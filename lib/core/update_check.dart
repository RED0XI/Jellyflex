import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'platform/app_paths.dart';
import 'version.dart';

/// Freiwillige Update-Prüfung (Standard: aus). Gefragt wird nur nach der
/// neuesten Versionsnummer – ohne Kennung, ohne Daten über dich oder deinen
/// Server. Geladen oder installiert wird nichts automatisch – nur auf Klick,
/// und gestartet wird ein Installer nur mit gültiger Signatur.
///
/// Ein Release enthält je Betriebssystem ein Paket samt Signatur (`.sig`):
/// - Windows: `Jellyflex-Setup-<Version>.exe` (Inno Setup, wird still ausgeführt)
/// - macOS: `Jellyflex-<Version>-macOS.zip` (die App; ersetzt nach dem Beenden die alte)
abstract final class UpdateCheck {
  /// Einzige Adresse, die dafür kontaktiert wird.
  static const feedUrl = 'https://api.github.com/repos/RED0XI/Jellyflex/releases/latest';

  /// Seite mit den Versionen (öffnet sich nur auf Klick im Browser).
  static const releasesPage = 'https://github.com/RED0XI/Jellyflex/releases';

  static final _version = RegExp(r'^v?(\d{1,4})\.(\d{1,4})\.(\d{1,4})$');

  /// Öffentlicher Schlüssel (Ed25519), mit dem jedes Paket signiert wird.
  /// Der geheime Teil liegt nur beim Herausgeber (siehe tool/sign_update.dart) –
  /// ein ausgetauschter oder beschädigter Installer wird nie gestartet.
  static const signingPublicKey = '+Y8cjS0D1ZCn3nUoIKtKG4xePI6nT9RGnP3J+gT8QXU=';

  /// Downloads nur von hier (die Signatur ist trotzdem die eigentliche Prüfung).
  static const _assetPrefix = 'https://github.com/RED0XI/Jellyflex/releases/download/';

  /// Neueste veröffentlichte Version (z. B. "0.3.0") oder `null`, falls
  /// nicht ermittelbar.
  static Future<String?> latestVersion({String url = feedUrl}) async => (await latestRelease(url: url))?.version;

  /// Neueste Version samt Installer und Signatur (soweit im Release vorhanden).
  static Future<UpdateRelease?> latestRelease({String url = feedUrl}) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = 'Jellyflex';
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      final response = await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode != HttpStatus.ok) return null;
      // Antwort begrenzen – eine Versionsangabe ist klein.
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 10))) {
        bytes.addAll(chunk);
        if (bytes.length > 512 * 1024) return null;
      }
      final json = jsonDecode(utf8.decode(bytes)) as Map;
      final tag = json['tag_name'];
      final match = tag is String ? _version.firstMatch(tag.trim()) : null;
      if (match == null) return null;
      final version = '${match[1]}.${match[2]}.${match[3]}';
      String? asset(String name) {
        for (final a in (json['assets'] as List?) ?? const []) {
          if (a is! Map || a['name'] != name) continue;
          final link = a['browser_download_url'];
          if (link is String && link.startsWith(_assetPrefix)) return link;
        }
        return null;
      }

      final installer = packageName(version);
      return UpdateRelease(version, installerUrl: asset(installer), signatureUrl: asset('$installer.sig'));
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Name des Update-Pakets für dieses Betriebssystem im Release.
  static String packageName(String version, {bool? macOS}) =>
      (macOS ?? Platform.isMacOS) ? 'Jellyflex-$version-macOS.zip' : 'Jellyflex-Setup-$version.exe';

  /// Kann sich die App an ihrem Ort selbst ersetzen? Unter Windows erledigt das der
  /// Installer. Unter macOS muss die App in einem beschreibbaren Ordner liegen (z. B.
  /// Programme) – nicht direkt aus dem Download-Abbild oder der App-Translokation.
  static bool get canSelfUpdate {
    if (Platform.isWindows) return true;
    if (!Platform.isMacOS) return false;
    final bundle = macAppBundle;
    if (bundle == null || bundle.contains('/AppTranslocation/') || bundle.startsWith('/Volumes/')) return false;
    final parent = Directory(bundle).parent;
    try {
      final probe = Directory(AppPaths.join(parent.path, '.jellyflex-update-probe-$pid'))..createSync();
      probe.deleteSync();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// macOS: Pfad der laufenden `Jellyflex.app` (oder `null`, z. B. beim Entwickeln).
  static String? get macAppBundle {
    // …/Jellyflex.app/Contents/MacOS/Jellyflex
    final bundle = File(Platform.resolvedExecutable).parent.parent.parent.path;
    return bundle.endsWith('.app') ? bundle : null;
  }

  /// Passt [signature] (Base64) zu [data] und dem eingebauten Schlüssel?
  static Future<bool> verify(List<int> data, String signature, {String publicKey = signingPublicKey}) async {
    try {
      final algorithm = Ed25519();
      return await algorithm.verify(
        data,
        signature: Signature(
          base64Decode(signature.trim()),
          publicKey: SimplePublicKey(base64Decode(publicKey), type: KeyPairType.ed25519),
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Installer und Signatur laden und prüfen. Liefert die geprüfte Datei – oder
  /// `null`, wenn etwas fehlt oder nicht stimmt (die Datei ist dann schon gelöscht).
  static Future<File?> downloadVerified(
    UpdateRelease release, {
    ValueChanged<double>? onProgress,
    @visibleForTesting String publicKey = signingPublicKey,
  }) async {
    final installerUrl = release.installerUrl;
    final signatureUrl = release.signatureUrl;
    if (installerUrl == null || signatureUrl == null) return null;
    final dir = Directory(AppPaths.join(Directory.systemTemp.path, 'JellyflexUpdate'))..createSync(recursive: true);
    final file = File(AppPaths.join(dir.path, packageName(release.version)));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..userAgent = 'Jellyflex';
    try {
      Future<List<int>> fetch(String url, int limit, {bool progress = false}) async {
        final response = await (await client.getUrl(Uri.parse(url))).close();
        if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}');
        final total = response.contentLength;
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(const Duration(seconds: 30))) {
          bytes.add(chunk);
          if (bytes.length > limit) throw const HttpException('zu groß');
          if (progress && total > 0) onProgress?.call(bytes.length / total);
        }
        return bytes.takeBytes();
      }

      final signature = utf8.decode(await fetch(signatureUrl, 4096));
      final data = await fetch(installerUrl, 500 * 1024 * 1024, progress: true);
      if (!await verify(data, signature, publicKey: publicKey)) return null;
      await file.writeAsBytes(data, flush: true);
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Geprüften Installer still (ohne Fragen) starten; die App beendet sich gleich danach.
  /// [relaunch]: Jellyflex nach dem Update wieder öffnen (sonst bleibt sie zu – z. B.
  /// beim Installieren während des Beendens).
  static Future<void> runInstaller(File installer, {bool relaunch = true}) async {
    if (Platform.isMacOS) return _replaceMacApp(installer, relaunch: relaunch);
    final script = File(AppPaths.join(installer.parent.path, 'run_update.cmd'));
    await script.writeAsString(installScript(installer.path, relaunch: relaunch, allUsers: _installedForAllUsers));
    // Über ein kleines Skript mit kurzer Pause: der Installer darf erst loslegen,
    // wenn diese App ganz beendet ist (sonst meldet er "Jellyflex läuft noch").
    await Process.start('cmd.exe', ['/c', script.path], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// macOS: geprüftes Paket entpacken, Code-Signatur der neuen App prüfen und ein
  /// kleines Skript starten, das nach dem Beenden dieser App die alte `.app` ersetzt.
  static Future<void> _replaceMacApp(File package, {required bool relaunch}) async {
    final target = macAppBundle;
    if (target == null) return;
    final staging = Directory(AppPaths.join(package.parent.path, 'staging'));
    if (staging.existsSync()) staging.deleteSync(recursive: true);
    staging.createSync(recursive: true);
    // ditto behält Rechte, Symlinks und Code-Signaturen bei (anders als ein reines Zip-Entpacken).
    final unzip = await Process.run('/usr/bin/ditto', ['-x', '-k', package.path, staging.path]);
    final app = AppPaths.join(staging.path, 'Jellyflex.app');
    if (unzip.exitCode != 0 || !Directory(app).existsSync()) {
      debugPrint('Update nicht entpackt: ${unzip.stderr}');
      return;
    }
    // Zweite Sicherung neben der Ed25519-Signatur: die App selbst muss unverändert signiert sein.
    final codesign = await Process.run('/usr/bin/codesign', ['--verify', '--deep', '--strict', app]);
    if (codesign.exitCode != 0) {
      debugPrint('Update-Signatur der App ungültig: ${codesign.stderr}');
      return;
    }
    final script = File(AppPaths.join(package.parent.path, 'run_update.sh'));
    await script.writeAsString(macInstallScript(app, target, pid: pid, relaunch: relaunch));
    await Process.start('/bin/sh', [script.path], mode: ProcessStartMode.detached);
    exit(0);
  }

  /// Inhalt des Ersetz-Skripts für macOS. Wartet, bis die App beendet ist, tauscht
  /// die `.app` aus (bei einem Fehler bleibt die alte erhalten) und öffnet sie ggf. neu.
  @visibleForTesting
  static String macInstallScript(String newApp, String target, {required int pid, required bool relaunch}) {
    String q(String s) => "'${s.replaceAll("'", r"'\''")}'";
    final old = q('$target.old-update');
    return [
      '#!/bin/sh',
      // Höchstens ~30 s auf das Beenden warten.
      'i=0; while kill -0 $pid 2>/dev/null && [ \$i -lt 150 ]; do sleep 0.2; i=\$((i+1)); done',
      'rm -rf $old',
      'if mv ${q(target)} $old; then',
      '  if mv ${q(newApp)} ${q(target)}; then rm -rf $old; else mv $old ${q(target)}; fi',
      'fi',
      if (relaunch) 'open ${q(target)}',
      '',
    ].join('\n');
  }

  /// Inhalt des Startskripts für den Installer (Windows).
  @visibleForTesting
  static String installScript(String installer, {required bool relaunch, required bool allUsers}) {
    final args = [
      '/VERYSILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      allUsers ? '/ALLUSERS' : '/CURRENTUSER',
      if (relaunch) '/RELAUNCH',
    ].join(' ');
    return '@echo off\r\nping -n 3 127.0.0.1 >nul\r\n"$installer" $args\r\n';
  }

  /// Wurde Jellyflex für alle Benutzer (unter "Programme") installiert? Dann das Update
  /// genauso – sonst entstünde eine zweite Installation nur für diesen Benutzer.
  static bool get _installedForAllUsers {
    final exe = Platform.resolvedExecutable.toLowerCase();
    return [
      Platform.environment['ProgramFiles'],
      Platform.environment['ProgramFiles(x86)'],
    ].whereType<String>().any((p) => exe.startsWith('${p.toLowerCase()}\\'));
  }

  // --- Automatisch installieren ---------------------------------------------

  /// Geprüfter Installer, der beim Beenden der App installiert wird (oder `null`).
  static File? _pendingInstaller;
  static bool _exitHookInstalled = false;

  /// Update beim Beenden installieren (still, ohne Neustart der App).
  static Future<void> installOnExit(File installer) async {
    _pendingInstaller = installer;
    if (_exitHookInstalled) return;
    _exitHookInstalled = true;
    windowManager.addListener(_ExitInstaller());
    await windowManager.setPreventClose(true);
  }

  /// Ist [latest] neuer als [current]? (Versionen im Format 1.2.3)
  static bool isNewer(String latest, [String current = appVersion]) {
    List<int> parts(String v) => v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final a = parts(latest);
    final b = parts(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Versionsseite im Browser öffnen (feste Adresse, nichts vom Server).
  static Future<void> openReleasesPage() => AppPaths.openUrl(releasesPage);
}

/// Beim Schließen des Fensters: wartendes Update still installieren, dann beenden.
class _ExitInstaller with WindowListener {
  @override
  void onWindowClose() async {
    final installer = UpdateCheck._pendingInstaller;
    if (installer != null && installer.existsSync()) {
      await UpdateCheck.runInstaller(installer, relaunch: false);
    }
    // Schließen-Sperre aufheben: unter macOS beendet destroy() die App über
    // NSApp.terminate, das sonst erneut hier nachfragen würde.
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }
}

/// Eine veröffentlichte Version mit (optional) Installer und Signatur.
class UpdateRelease {
  const UpdateRelease(this.version, {this.installerUrl, this.signatureUrl});

  final String version;
  final String? installerUrl;
  final String? signatureUrl;

  /// Lässt sich direkt (geprüft) installieren?
  bool get canInstall => installerUrl != null && signatureUrl != null && UpdateCheck.canSelfUpdate;
}
