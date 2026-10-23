import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/jellyfin_api.dart';
import '../../core/models.dart';
import '../../core/session.dart';
import '../../theme.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/buttons.dart';
import '../../widgets/focusable.dart';
import '../../l10n/strings.dart';
import '../../core/image_cache.dart';

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
  final _passFocus = FocusNode();

  ServerInfo? _server;
  bool _busy = false;
  String? _error;

  bool _quickConnectAvailable = false;
  String? _quickConnectCode;
  Timer? _quickConnectTimer;

  /// Gespeicherte Konten ausblenden und ein neues hinzufügen.
  bool _addingAccount = false;

  /// Benutzer, die der Server öffentlich anzeigt (Klick füllt den Namen aus).
  List<Json> _publicUsers = const [];

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
    _passFocus.dispose();
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
      final (qc, users) = await (api.isQuickConnectEnabled(), api.getPublicUsers()).wait;
      if (!mounted) return;
      setState(() {
        _server = server;
        _quickConnectAvailable = qc;
        _publicUsers = users;
      });
      _userFocus.requestFocus();
    } catch (_) {
      setState(() => _error = tr.noServerAtAddress);
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
            ? tr.wrongCredentials
            : tr.signInFailedCode('${status ?? e.type.name}'),
      );
    } catch (e) {
      setState(() => _error = tr.signInFailed(e));
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
              _error = tr.quickConnectExpired;
            });
          }
        }
      });
    } catch (_) {
      setState(() => _error = tr.quickConnectFailed);
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

  /// Öffentlicher Benutzer gewählt: ohne Passwort direkt anmelden, sonst Namen eintragen.
  Future<void> _pickPublicUser(Json user) async {
    _userCtrl.text = (user['Name'] as String?) ?? '';
    if (user['HasPassword'] == false) {
      _passCtrl.clear();
      await _login();
    } else {
      _passFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(savedAccountsProvider).value ?? const <AuthSession>[];
    final showProfiles = accounts.isNotEmpty && !_addingAccount && _server == null;

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
                  Text(tr.tagline, style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 36),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: showProfiles ? 560 : 420,
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
                        child: showProfiles
                            ? _buildProfiles(accounts)
                            : _server == null
                            ? _buildServerStep(canGoBack: accounts.isNotEmpty)
                            : _buildLoginStep(),
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

  /// "Wer schaut?" – gespeicherte Konten zum schnellen Wechseln.
  Widget _buildProfiles(List<AuthSession> accounts) {
    return Column(
      key: const ValueKey('profiles'),
      children: [
        Text(tr.whoIsWatching, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          alignment: WrapAlignment.center,
          children: [
            for (final a in accounts)
              _ProfileTile(
                name: a.userName,
                subtitle: a.serverName,
                imageUrl: a.userImageUrl,
                onTap: () => ref.read(sessionProvider.notifier).activate(a),
                onForget: () => ref.read(sessionProvider.notifier).forgetAccount(a),
              ),
            _ProfileTile(
              name: tr.addAccount,
              icon: Icons.add_rounded,
              onTap: () => setState(() => _addingAccount = true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildServerStep({bool canGoBack = false}) {
    return Column(
      key: const ValueKey('server'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canGoBack)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _addingAccount = false),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(tr.toProfileSelection),
            ),
          ),
        Text(tr.connectServer, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(tr.enterServerAddress, style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        TextField(
          controller: _serverCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr.serverAddress,
            hintText: 'https://jellyfin.example.com',
            prefixIcon: Icon(Icons.dns_rounded),
          ),
          onSubmitted: (_) => _connect(),
        ),
        _ErrorText(_error),
        const SizedBox(height: 24),
        PrimaryButton(label: tr.connect, onPressed: _connect, loading: _busy),
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
          Text(tr.quickConnectHint, style: TextStyle(color: AppColors.textSecondary)),
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
            child: Text(tr.cancel),
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
            IconButton(onPressed: _back, icon: const Icon(Icons.arrow_back_rounded), tooltip: tr.otherServer),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr.signIn, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                  Text(
                    '${server.name} · Jellyfin ${server.version}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (server.insecure) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x33FFB020),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x66FFB020)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_open_rounded, size: 20, color: Color(0xFFFFC14D)),
                const SizedBox(width: 10),
                Expanded(child: Text(tr.unencryptedWarning, style: const TextStyle(fontSize: 13))),
              ],
            ),
          ),
        ],
        if (_publicUsers.isNotEmpty) ...[
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final u in _publicUsers)
                _ProfileTile(
                  name: (u['Name'] as String?) ?? '',
                  imageUrl: u['PrimaryImageTag'] == null
                      ? null
                      : '${server.url}/UserImage?${Uri(queryParameters: {'userId': u['Id'] as String, 'tag': u['PrimaryImageTag'] as String}).query}',
                  small: true,
                  onTap: () => _pickPublicUser(u),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _userCtrl,
          focusNode: _userFocus,
          decoration: InputDecoration(labelText: tr.username, prefixIcon: Icon(Icons.person_rounded)),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          focusNode: _passFocus,
          obscureText: true,
          decoration: InputDecoration(labelText: tr.password, prefixIcon: Icon(Icons.lock_rounded)),
          onSubmitted: (_) => _login(),
        ),
        _ErrorText(_error),
        const SizedBox(height: 24),
        PrimaryButton(label: tr.signIn, onPressed: _login, loading: _busy),
        if (_quickConnectAvailable) ...[
          const SizedBox(height: 12),
          Center(
            child: GlassButton(
              label: tr.signInWithQuickConnect,
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

/// Profilkachel: rundes Bild (oder Symbol) mit Namen; Rechtsklick → entfernen.
class _ProfileTile extends StatefulWidget {
  const _ProfileTile({
    required this.name,
    required this.onTap,
    this.subtitle,
    this.imageUrl,
    this.icon,
    this.onForget,
    this.small = false,
  });

  final String name;
  final String? subtitle;
  final String? imageUrl;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onForget;
  final bool small;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  Future<void> _showMenu(Offset position) async {
    final onForget = widget.onForget;
    if (onForget == null) return;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(position & const Size(1, 1), Offset.zero & overlay.size),
      items: [
        PopupMenuItem(
          value: 'forget',
          child: Row(
            children: [Icon(Icons.person_remove_outlined, size: 20), SizedBox(width: 12), Text(tr.removeAccount)],
          ),
        ),
      ],
    );
    if (choice == 'forget') onForget();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.small ? 56.0 : 104.0;
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    return Focusable(
      onTap: widget.onTap,
      onSecondaryTap: widget.onForget == null ? null : _showMenu,
      builder: (context, hovered) => SizedBox(
        width: widget.small ? 72 : 130,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.28),
                gradient: widget.icon == null ? AppColors.accentGradient : null,
                color: widget.icon != null ? Colors.white.withValues(alpha: hovered ? 0.16 : 0.08) : null,
                border: Border.all(color: hovered ? Colors.white : Colors.transparent, width: 2.5),
              ),
              child: widget.icon != null
                  ? Icon(widget.icon, size: size * 0.45, color: AppColors.textSecondary)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Text(
                            initial,
                            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (widget.imageUrl != null)
                          Image(
                            image: CachedNetworkImage(widget.imageUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.small ? 12.5 : 15,
                fontWeight: FontWeight.w600,
                color: hovered ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (widget.subtitle != null)
              Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
