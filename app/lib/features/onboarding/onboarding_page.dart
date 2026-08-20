import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/session/session_controller.dart';
import '../../core/theme/brightness_provider.dart';
import '../../core/theme/squircle_button.dart';
import '../../core/theme/surface_card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/roost_input.dart';

/// Login. Sign in with registration number or email + password (FR1), with a
/// Face ID / fingerprint option (FR3) and a create-account sheet (FR2).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

final _regNoRe = RegExp(r'^\d{11}$');
final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$', caseSensitive: false);
bool validIdentifier(String s) =>
    _regNoRe.hasMatch(s.trim()) || _emailRe.hasMatch(s.trim());
bool validPassword(String s) =>
    s.length >= 8 &&
    RegExp(r'[A-Za-z]').hasMatch(s) &&
    RegExp(r'\d').hasMatch(s);

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final id = _id.text.trim();
    if (!validIdentifier(id)) {
      setState(
        () => _error = 'Enter your registration number or email address.',
      );
      return;
    }
    if (!validPassword(_pw.text)) {
      setState(
        () => _error =
            'Password must be at least 8 characters with a letter and a number.',
      );
      return;
    }
    await _authenticate(id, _pw.text, register: false);
  }

  /// Sign in (or register) via the session controller, then bootstrap + navigate.
  /// In demo mode this returns instantly; live mode may pause on a cold backend.
  Future<void> _authenticate(
    String identifier,
    String password, {
    required bool register,
  }) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await ref
        .read(sessionProvider.notifier)
        .signIn(identifier: identifier, password: password, register: register);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      context.go('/home');
    } else {
      setState(() => _error = err);
    }
  }

  Future<void> _biometric() async {
    final auth = LocalAuthentication();
    try {
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;
      final ok = (supported || canCheck)
          ? await auth.authenticate(
              localizedReason: 'Unlock Roost to view your hostel',
              options: const AuthenticationOptions(stickyAuth: true),
            )
          : true; // fallback on devices/web without biometrics
      if (!ok || !mounted) return;
      setState(() {
        _error = null;
        _busy = true;
      });
      final restored = await ref
          .read(sessionProvider.notifier)
          .restoreSession();
      if (!mounted) return;
      setState(() => _busy = false);
      if (restored) {
        context.go('/home');
      } else {
        setState(
          () => _error =
              'Sign in with your password once — then Face ID / fingerprint unlocks next time.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brightnessProvider);
    return Scaffold(
      backgroundColor: RoostColors.surface0,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RoostSpacing.xxl,
            0,
            RoostSpacing.xxl,
            RoostSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),
                _Wordmark(),
                const SizedBox(height: RoostSpacing.sm),
                Text(
                  'FUTO Hostel Reservation',
                  style: TextStyle(
                    fontSize: 16,
                    color: RoostColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find a bed, pay, and get your allocation — from your phone.',
                  style: TextStyle(
                    fontSize: 14,
                    color: RoostColors.textTertiary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: RoostSpacing.xxxl),
                RoostSurfaceCard(
                  floating: true,
                  padding: const EdgeInsets.all(RoostSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Registration number or email'),
                      RoostTextField(
                        controller: _id,
                        hint: '20211234567',
                        icon: PhosphorIcons.identificationCard(),
                        keyboardType: TextInputType.emailAddress,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Password'),
                      RoostTextField(
                        controller: _pw,
                        hint: '••••••••',
                        icon: PhosphorIcons.lockSimple(),
                        obscure: _obscure,
                        action: TextInputAction.done,
                        onSubmitted: (_) => _signIn(),
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(
                            _obscure
                                ? PhosphorIcons.eye()
                                : PhosphorIcons.eyeSlash(),
                            size: 20,
                            color: RoostColors.textTertiary,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: RoostSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIcons.warningCircle(),
                              size: 16,
                              color: RoostColors.negative,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: RoostColors.negative,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: RoostSpacing.xl),
                      RoostButton(
                        label: 'Sign in',
                        isLoading: _busy,
                        onPressed: _busy ? null : _signIn,
                      ),
                      const SizedBox(height: RoostSpacing.md),
                      RoostButton(
                        label: 'Use Face ID / Fingerprint',
                        variant: RoostButtonVariant.secondary,
                        icon: PhosphorIcons.fingerprint(),
                        onPressed: _busy ? null : _biometric,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RoostSpacing.xl),
                Center(
                  child: GestureDetector(
                    onTap: _busy ? null : () => context.push('/signup'),
                    behavior: HitTestBehavior.opaque,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: RoostColors.textSecondary,
                          fontFamily: 'Montserrat',
                        ),
                        children: [
                          const TextSpan(text: 'New here?  '),
                          TextSpan(
                            text: 'Create account',
                            style: TextStyle(
                              color: RoostColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RoostSpacing.xxxl),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.shieldCheck(),
                        size: 16,
                        color: RoostColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Secured for FUTO students',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: RoostColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: RoostSpacing.sm, left: 2),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: RoostColors.textSecondary,
      ),
    ),
  );
}

/// Full-screen create-account page. Mirrors the sign-in screen (so it can't be
/// dismissed by tapping away like a sheet), with its own show/hide password
/// toggles and an "Already have an account? Sign in" CTA that returns to sign-in.
class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _name = TextEditingController();
  final _regNo = TextEditingController();
  final _email = TextEditingController();
  final _dept = TextEditingController();
  final _level = TextEditingController();
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _pwObscure = true;
  bool _confirmObscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _regNo.dispose();
    _email.dispose();
    _dept.dispose();
    _level.dispose();
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final regNo = _regNo.text.trim();
    final email = _email.text.trim();
    final dept = _dept.text.trim();
    final level = _level.text.trim();
    if ([name, regNo, email, dept, level].any((field) => field.isEmpty)) {
      setState(
        () => _error =
            'Complete every profile field before creating your account.',
      );
      return;
    }
    if (!_regNoRe.hasMatch(regNo)) {
      setState(() => _error = 'Enter an 11-digit registration number.');
      return;
    }
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (!validPassword(_pw.text)) {
      setState(
        () => _error =
            'Password must be at least 8 characters with a letter and a number.',
      );
      return;
    }
    if (_pw.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    final err = await ref
        .read(sessionProvider.notifier)
        .signIn(
          identifier: regNo,
          password: _pw.text,
          register: true,
          name: name,
          regNo: regNo,
          email: email,
          dept: dept,
          level: level,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      context.go('/home');
    } else {
      setState(() => _error = err);
    }
  }

  void _backToSignIn() => context.canPop() ? context.pop() : context.go('/');

  Widget _eyeSuffix(bool obscure, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Icon(
      obscure ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(),
      size: 20,
      color: RoostColors.textTertiary,
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(brightnessProvider);
    return Scaffold(
      backgroundColor: RoostColors.surface0,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            RoostSpacing.xxl,
            0,
            RoostSpacing.xxl,
            RoostSpacing.xxl,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.vertical -
                  48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 56),
                _Wordmark(),
                const SizedBox(height: RoostSpacing.sm),
                Text(
                  'FUTO Hostel Reservation',
                  style: TextStyle(
                    fontSize: 16,
                    color: RoostColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create your account to reserve a bed.',
                  style: TextStyle(
                    fontSize: 14,
                    color: RoostColors.textTertiary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: RoostSpacing.xxxl),
                RoostSurfaceCard(
                  floating: true,
                  padding: const EdgeInsets.all(RoostSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Full name'),
                      RoostTextField(
                        controller: _name,
                        hint: 'Your full name',
                        icon: PhosphorIcons.user(),
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Registration number'),
                      RoostTextField(
                        controller: _regNo,
                        hint: '20211234567',
                        icon: PhosphorIcons.identificationCard(),
                        keyboardType: TextInputType.number,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Email address'),
                      RoostTextField(
                        controller: _email,
                        hint: 'you@example.com',
                        icon: PhosphorIcons.envelope(),
                        keyboardType: TextInputType.emailAddress,
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Department'),
                      RoostTextField(
                        controller: _dept,
                        hint: 'Software Engineering',
                        icon: PhosphorIcons.buildings(),
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Level'),
                      RoostTextField(
                        controller: _level,
                        hint: '400 Level',
                        icon: PhosphorIcons.graduationCap(),
                        action: TextInputAction.next,
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Password'),
                      RoostTextField(
                        controller: _pw,
                        hint: '••••••••',
                        icon: PhosphorIcons.lockSimple(),
                        obscure: _pwObscure,
                        action: TextInputAction.next,
                        suffix: _eyeSuffix(
                          _pwObscure,
                          () => setState(() => _pwObscure = !_pwObscure),
                        ),
                      ),
                      const SizedBox(height: RoostSpacing.lg),
                      _label('Confirm password'),
                      RoostTextField(
                        controller: _confirm,
                        hint: '••••••••',
                        icon: PhosphorIcons.lockSimple(),
                        obscure: _confirmObscure,
                        action: TextInputAction.done,
                        onSubmitted: (_) => _create(),
                        suffix: _eyeSuffix(
                          _confirmObscure,
                          () => setState(
                            () => _confirmObscure = !_confirmObscure,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: RoostSpacing.md),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              PhosphorIcons.warningCircle(),
                              size: 16,
                              color: RoostColors.negative,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: RoostColors.negative,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: RoostSpacing.xl),
                      RoostButton(
                        label: 'Create account',
                        isLoading: _busy,
                        onPressed: _busy ? null : _create,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RoostSpacing.xl),
                Center(
                  child: GestureDetector(
                    onTap: _busy ? null : _backToSignIn,
                    behavior: HitTestBehavior.opaque,
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: RoostColors.textSecondary,
                          fontFamily: 'Montserrat',
                        ),
                        children: [
                          const TextSpan(text: 'Already have an account?  '),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: RoostColors.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: RoostSpacing.xxxl),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.shieldCheck(),
                        size: 16,
                        color: RoostColors.textTertiary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Secured for FUTO students',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: RoostColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: RoostSpacing.sm, left: 2),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: RoostColors.textSecondary,
      ),
    ),
  );
}

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Montserrat',
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        children: [
          TextSpan(
            text: 'Roost',
            style: TextStyle(color: RoostColors.textPrimary),
          ),
          TextSpan(
            text: '.',
            style: TextStyle(color: RoostColors.accent),
          ),
        ],
      ),
    );
  }
}
