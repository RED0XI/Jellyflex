import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'settings.dart' show appDataDir;
import 'platform/app_paths.dart';

/// Zertifikatsprüfung für den Video-Player.
///
/// mpv (bzw. sein TLS über mbedTLS) prüft Zertifikate von sich aus NICHT und
/// kennt auch keine vertrauenswürdigen Stammzertifikate des Systems. Ohne das
/// könnte sich jemand im Netz als der Server ausgeben und bekäme mit den
/// Video-Anfragen das Anmelde-Token. Deshalb:
/// 1. die Stammzertifikate des Systems als PEM-Datei exportieren – exakt dieselben,
///    denen auch Windows bzw. macOS vertraut (inkl. selbst hinzugefügter, z. B. einer
///    eigenen Zertifizierungsstelle fürs Heimnetz),
/// 2. dem Player `tls-verify=yes` und diese Datei geben.
abstract final class SystemCerts {
  static Future<String?>? _caFile;

  /// Pfad der exportierten Stammzertifikate (einmal je Programmstart erzeugt).
  static Future<String?> caFile() => _caFile ??= _export();

  /// Für [player]: Zertifikate prüfen, mit den Stammzertifikaten von Windows.
  /// Schlägt der Export fehl, bleibt die Prüfung trotzdem an (lieber kein Video
  /// als ein ungeprüftes).
  static Future<void> secure(Player player) async {
    final native = player.platform;
    if (native is! NativePlayer) return;
    try {
      await native.setProperty('tls-verify', 'yes');
      final file = await caFile();
      if (file != null) await native.setProperty('tls-ca-file', file);
    } catch (e) {
      debugPrint('Zertifikatsprüfung nicht gesetzt: $e');
    }
  }

  static const _shell = MethodChannel('jellyflex/shell');

  static Future<String?> _export() async {
    if (!Platform.isWindows && !Platform.isMacOS) return null;
    try {
      final pem = Platform.isWindows ? _windowsRootsAsPem() : await _macRootsAsPem();
      if (pem.isEmpty) return null;
      final dir = appDataDir;
      await dir.create(recursive: true);
      final file = File(AppPaths.join(dir.path, 'ca-roots.pem'));
      if (!await file.exists() || await file.readAsString() != pem) {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(pem, flush: true);
        await tmp.rename(file.path);
      }
      return file.path;
    } catch (e) {
      debugPrint('Stammzertifikate nicht exportiert: $e');
      return null;
    }
  }

  /// macOS: vertrauenswürdige Stammzertifikate (System, Administrator, Benutzer) vom
  /// Runner (macos/Runner/AppShell.swift) als DER-Liste.
  static Future<String> _macRootsAsPem() async {
    final List<Object?>? roots;
    try {
      roots = await _shell.invokeMethod<List<Object?>>('trustedRoots');
    } on MissingPluginException {
      return '';
    }
    final out = StringBuffer();
    for (final der in roots ?? const []) {
      if (der is Uint8List && !usesBrokenHash(der)) out.write(derToPem(der));
    }
    return out.toString();
  }

  /// Ein Zertifikat (DER) als PEM-Block.
  @visibleForTesting
  static String derToPem(Uint8List der) {
    final out = StringBuffer();
    final b64 = base64.encode(der);
    out.writeln('-----BEGIN CERTIFICATE-----');
    for (var i = 0; i < b64.length; i += 64) {
      out.writeln(b64.substring(i, i + 64 > b64.length ? b64.length : i + 64));
    }
    out.writeln('-----END CERTIFICATE-----');
    return out.toString();
  }

  /// Alle Zertifikate aus dem Windows-Speicher "ROOT" (vertrauenswürdige
  /// Stammzertifizierungsstellen des Benutzers inkl. der des Computers).
  static String _windowsRootsAsPem() {
    final crypt32 = DynamicLibrary.open('crypt32.dll');
    final open = crypt32
        .lookupFunction<Pointer<Void> Function(IntPtr, Pointer<Utf16>), Pointer<Void> Function(int, Pointer<Utf16>)>(
          'CertOpenSystemStoreW',
        );
    final enumerate = crypt32
        .lookupFunction<
          Pointer<_CertContext> Function(Pointer<Void>, Pointer<_CertContext>),
          Pointer<_CertContext> Function(Pointer<Void>, Pointer<_CertContext>)
        >('CertEnumCertificatesInStore');
    final close = crypt32.lookupFunction<Int32 Function(Pointer<Void>, Uint32), int Function(Pointer<Void>, int)>(
      'CertCloseStore',
    );

    final name = 'ROOT'.toNativeUtf16();
    final store = open(0, name);
    malloc.free(name);
    if (store == nullptr) return '';
    final out = StringBuffer();
    try {
      var cert = enumerate(store, nullptr);
      while (cert != nullptr) {
        final der = cert.ref.pbCertEncoded.asTypedList(cert.ref.cbCertEncoded);
        if (!usesBrokenHash(der)) out.write(derToPem(der));
        // Gibt den vorherigen Kontext selbst frei.
        cert = enumerate(store, cert);
      }
    } finally {
      close(store, 0);
    }
    return out.toString();
  }

  /// Ist das Zertifikat mit MD2, MD4 oder MD5 signiert? Diese Verfahren sind
  /// längst gebrochen (Windows behält solche Uralt-Stammzertifikate nur für
  /// alte Zeitstempel); mbedTLS kann MD2 nicht einmal lesen und verwirft dann
  /// die ganze Datei. Liest dazu nur das Feld "signatureAlgorithm" aus dem DER.
  @visibleForTesting
  static bool usesBrokenHash(Uint8List der) {
    try {
      var pos = 0;
      // Liest Kopf (Typ + Länge) eines DER-Elements; liefert (Typ, Länge, Inhaltsbeginn).
      (int, int, int) header(int at) {
        final tag = der[at];
        var len = der[at + 1];
        var start = at + 2;
        if (len & 0x80 != 0) {
          final n = len & 0x7F;
          len = 0;
          for (var i = 0; i < n; i++) {
            len = (len << 8) | der[start + i];
          }
          start += n;
        }
        return (tag, len, start);
      }

      final (_, _, certStart) = header(pos); // Certificate ::= SEQUENCE
      final (_, tbsLen, tbsStart) = header(certStart); // tbsCertificate überspringen
      pos = tbsStart + tbsLen;
      final (_, _, algStart) = header(pos); // signatureAlgorithm ::= SEQUENCE
      final (tag, oidLen, oidStart) = header(algStart); // OBJECT IDENTIFIER
      if (tag != 0x06) return false;
      // 1.2.840.113549.1.1.{2,3,4} = md2/md4/md5WithRSAEncryption
      const rsaPrefix = [0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01];
      if (oidLen != 9) return false;
      for (var i = 0; i < rsaPrefix.length; i++) {
        if (der[oidStart + i] != rsaPrefix[i]) return false;
      }
      final last = der[oidStart + 8];
      return last == 2 || last == 3 || last == 4;
    } catch (_) {
      return true; // Unlesbar → lieber weglassen.
    }
  }
}

final class _CertContext extends Struct {
  @Uint32()
  external int dwCertEncodingType;
  external Pointer<Uint8> pbCertEncoded;
  @Uint32()
  external int cbCertEncoded;
  external Pointer<Void> pCertInfo;
  external Pointer<Void> hCertStore;
}
