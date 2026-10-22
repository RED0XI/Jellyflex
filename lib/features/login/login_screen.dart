import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/jellyfin_api.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _serverCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _userFocus = FocusNode();

  ServerInfo? _server;
  bool _busy = false;
  String? _error;

  bool _quickConnectAvailable = false;
  String? _quickConnectCode;
  Timer? _quickConnectTimer;

  @override
  void initState() {
    super.initState();
    SessionController.lastServer().then((url) {
      if (url != null && mounted && _serverCtrl.text.isEmpty) _serverCtrl.text = url;
    });
  }

  @override
  void dispose() {
    _quickConnectTimer?.cancel();
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_serverCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final server = await JellyfinApi.probe(_serverCtrl.text);
      final api = await SessionController.anonymousApi(server);
      final qc = await api.isQuickConnectEnabled();
      if (!mounted) return;
      setState(() {
        _server = server;
        _quickConnectAvailable = qc;
      });
      _userFocus.requestFocus();
    } catch (_) {
      setState(() => _error = 'Unter dieser Adresse wurde kein Jellyfin-Server gefunden.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    final server = _server;
    if (server == null || _userCtrl.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).loginWithPassword(server, _userCtrl.text.trim(), _passCtrl.text);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      setState(
        () => _error = status == 401 || status == 400
            ? 'Benutzername oder Passwort ist falsch.'
            : 'Anmeldung fehlgeschlagen (${status ?? e.type.name}).',
      );
    } catch (e) {
      setState(() => _error = 'Anmeldung fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startQuickConnect() async {
    final server = _server;
    if (server == null) return;
    setState(() => _error = null);
    try {
      final api = await SessionController.anonymousApi(server);
      final state = await api.initiateQuickConnect();
      setState(() => _quickConnectCode = state.code);
      _quickConnectTimer?.cancel();
      _quickConnectTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        try {
          final s = await api.checkQuickConnect(state.secret);
          if (s.authenticated) {
            timer.cancel();
            await ref.read(sessionProvider.notifier).loginWithQuickConnect(server, state.secret);
          }
        } catch (_) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _quickConnectCode = null;
              _error = 'Quick Connect ist abgelaufen. Bitte erneut versuchen.';
            });
          }
        }
      });
    } catch (_) {
      setState(() => _error = 'Quick Connect konnte nicht gestartet werden.');
    }
  }

  void _back() {
    _quickConnectTimer?.cancel();
    setState(() {
      _server = null;
      _quickConnectCode = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 42),
                  const SizedBox(height: 8),
                  const Text('Dein Kino. Auf dem Desktop.', style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 36),
                  Container(
                    width: 420,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 60, offset: Offset(0, 20))],
                    ),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _server == null ? _buildServerStep() : _buildLoginStep(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerStep() {
    return Column(
      key: const ValueKey('server'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Server verbinden', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Gib die Adresse deines Jellyfin-Servers ein.', style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        TextField(
          controller: _serverCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Server-Adresse',
            hintText: 'https://jellyfin.example.com',
            prefixIcon: Icon(Icons.dns_rounded),
          ),
          onSubmitted: (_) => _connect(),
        ),
        _ErrorText(_error),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Verbinden', onPressed: _connect, loading: _busy),
      ],
    );
  }

  Widget _buildLoginStep() {
    final server = _server!;
    if (_quickConnectCode != null) {
      return Column(
        key: const ValueKey('qc'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Quick Connect', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Öffne Jellyfin auf einem angemeldeten Gerät → Profil → Quick Connect und gib diesen Code ein:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          Center(
            child: ShaderMask(
              shaderCallback: (b) => AppColors.accentGradient.createShader(b),
              child: Text(
                _quickConnectCode!,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 10,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () {
              _quickConnectTimer?.cancel();
              setState(() => _quickConnectCode = null);
            },
            child: const Text('Abbrechen'),
          ),
        ],
      );
    }

    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Anderer Server'),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Anmelden', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(
                    '${server.name} · Jellyfin ${server.version}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _userCtrl,
          focusNode: _userFocus,
          decoration: const InputDecoration(labelText: 'Benutzername', prefixIcon: Icon(Icons.person_rounded)),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Passwort', prefixIcon: Icon(Icons.lock_rounded)),
          onSubmitted: (_) => _login(),
        ),
        _ErrorText(_error),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Anmelden', onPressed: _login, loading: _busy),
        if (_quickConnectAvailable) ...[
          const SizedBox(height: 12),
          Center(
            child: GlassButton(
              label: 'Mit Quick Connect anmelden',
              icon: Icons.bolt_rounded,
              onPressed: _startQuickConnect,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF6B6B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error!, style: const TextStyle(color: Color(0xFFFF8A8A))),
          ),
        ],
      ),
    );
  }
}

/// Langsam wandernde Farbflächen im Hintergrund.
class _AmbientBackground extends StatefulWidget {
  const _AmbientBackground();

  @override
  State<_AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<_AmbientBackground> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_anim.value);
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.8 + t * 0.5, -0.7 + t * 0.3),
              radius: 1.1,
              colors: [AppColors.accent.withValues(alpha: 0.28), AppColors.background.withValues(alpha: 0)],
            ),
          ),
          foregroundDecoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.9 - t * 0.4, 0.8 - t * 0.3),
              radius: 1.0,
              colors: [AppColors.accentAlt.withValues(alpha: 0.20), AppColors.background.withValues(alpha: 0)],
            ),
          ),
        );
      },
    );
  }
}
