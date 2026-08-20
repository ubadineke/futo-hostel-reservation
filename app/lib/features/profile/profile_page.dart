import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/demo/hostel_data.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/brightness_provider.dart';
import '../../core/theme/squircle_button.dart';
import '../../core/theme/surface_card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/hostel_glyph.dart';
import '../../core/widgets/roost_avatar.dart';
import '../../core/widgets/roost_input.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/wavy_sheet.dart';

/// Profile + settings (identity, current stay, appearance toggle, sign out).
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(brightnessProvider);
    final student = ref.watch(sessionProvider) ?? Student.demo();
    final reservations = ref.watch(reservationsProvider);
    final activeList = reservations
        .where((r) => r.status == RoostStatus.paid)
        .toList();
    final active = activeList.isEmpty ? null : activeList.first;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          RoostSpacing.xl,
          RoostSpacing.lg,
          RoostSpacing.xl,
          RoostSpacing.xxl,
        ),
        children: [
          Row(
            children: [
              Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
              const Spacer(),
              GestureDetector(
                onTap: () => _settingsSheet(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: RoostColors.surface1,
                    shape: SmoothRectangleBorder(
                      side: BorderSide(
                        color: RoostColors.borderSubtle,
                        width: 0.5,
                      ),
                      borderRadius: const SmoothBorderRadius.all(
                        SmoothRadius(
                          cornerRadius: RoostRadius.md,
                          cornerSmoothing: 0.6,
                        ),
                      ),
                    ),
                  ),
                  child: Icon(
                    PhosphorIcons.gearSix(),
                    size: 20,
                    color: RoostColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RoostSpacing.lg),
          RoostSurfaceCard(
            floating: true,
            child: Column(
              children: [
                Row(
                  children: [
                    RoostAvatar(
                      label: student.displayName,
                      size: 60,
                      accent: true,
                    ),
                    const SizedBox(width: RoostSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.displayName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student.displayRegNo,
                            style: TextStyle(
                              fontSize: 14,
                              color: RoostColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RoostSpacing.lg),
                Divider(height: 1, color: RoostColors.borderSubtle),
                const SizedBox(height: RoostSpacing.md),
                Row(
                  children: [
                    Text(
                      'Personal details',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: RoostColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _editProfileSheet(context, ref, student),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 2,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              PhosphorIcons.pencilSimple(),
                              size: 15,
                              color: RoostColors.accent,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: RoostColors.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RoostSpacing.xs),
                _kv('Department', student.displayDept),
                _kv('Level', student.displayLevel),
                _kv('School email', student.displayEmail),
              ],
            ),
          ),
          const SizedBox(height: RoostSpacing.lg),
          Text('Your stay', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: RoostSpacing.md),
          if (active != null)
            RoostSurfaceCard(
              floating: true,
              padding: const EdgeInsets.all(RoostSpacing.lg),
              child: Row(
                children: [
                  HostelGlyph(
                    code: HostelData.byId(active.hostelId).code,
                    size: 46,
                    accent: true,
                  ),
                  const SizedBox(width: RoostSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          HostelData.byId(active.hostelId).name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Room ${active.roomIndex}  ·  Bed ${active.bed}',
                          style: TextStyle(
                            fontSize: 13,
                            color: RoostColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(RoostStatus.paid),
                ],
              ),
            )
          else
            RoostSurfaceCard(
              floating: true,
              padding: const EdgeInsets.all(RoostSpacing.lg),
              child: Row(
                children: [
                  Icon(
                    PhosphorIcons.bed(),
                    size: 24,
                    color: RoostColors.textTertiary,
                  ),
                  const SizedBox(width: RoostSpacing.md),
                  Expanded(
                    child: Text(
                      'No active booking yet — reserve a bed to see your allocation here.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: RoostColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: RoostSpacing.lg),
          RoostSurfaceCard(
            floating: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MenuItem(
                  icon: PhosphorIcons.question(),
                  label: 'Help & support',
                ),
                _MenuItem(icon: PhosphorIcons.info(), label: 'About Roost'),
                _MenuItem(
                  icon: PhosphorIcons.fileText(),
                  label: 'Terms & privacy',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Text(
            k,
            style: TextStyle(fontSize: 13, color: RoostColors.textTertiary),
          ),
        ),
        const SizedBox(width: RoostSpacing.lg),
        Expanded(
          flex: 6,
          child: Text(
            v,
            textAlign: TextAlign.left,
            softWrap: true,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: RoostColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _editProfileSheet(
    BuildContext context,
    WidgetRef ref,
    Student student,
  ) async {
    final saved = await showRoostWavySheet<bool>(
      context: context,
      headerHeight: 136,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.userCircleGear(),
            size: 30,
            color: RoostColors.onAccent,
          ),
          const SizedBox(height: RoostSpacing.sm),
          Text(
            'Edit profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: RoostColors.onAccent,
            ),
          ),
        ],
      ),
      child: _EditProfileForm(student: student),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    }
  }

  void _settingsSheet(BuildContext context, WidgetRef ref) {
    showRoostWavySheet(
      context: context,
      headerGradient: RoostGradients.graphiteHeader,
      headerForeground: RoostColors.textPrimary,
      headerHeight: 132,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.gearSix(),
            size: 28,
            color: RoostColors.textPrimary,
          ),
          const SizedBox(height: 6),
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: RoostColors.textPrimary,
            ),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RoostSpacing.xl,
          RoostSpacing.lg,
          RoostSpacing.xl,
          RoostSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: RoostColors.textSecondary,
              ),
            ),
            const SizedBox(height: RoostSpacing.sm),
            const _AppearanceToggle(),
            const SizedBox(height: RoostSpacing.xl),
            RoostButton(
              label: 'Sign out',
              variant: RoostButtonVariant.destructive,
              icon: PhosphorIcons.signOut(),
              onPressed: () async {
                Navigator.of(context).maybePop();
                await ref.read(sessionProvider.notifier).signOut();
                if (context.mounted) context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileForm extends ConsumerStatefulWidget {
  const _EditProfileForm({required this.student});
  final Student student;

  @override
  ConsumerState<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends ConsumerState<_EditProfileForm> {
  late final _name = TextEditingController(text: widget.student.name ?? '');
  late final _email = TextEditingController(text: widget.student.email ?? '');
  late final _dept = TextEditingController(text: widget.student.dept ?? '');
  late final _level = TextEditingController(text: widget.student.level ?? '');
  bool _saving = false;
  String? _error;

  static final _emailPattern = RegExp(
    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    caseSensitive: false,
  );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _dept.dispose();
    _level.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final dept = _dept.text.trim();
    final level = _level.text.trim();
    if (name.isEmpty && email.isEmpty && dept.isEmpty && level.isEmpty) {
      setState(() => _error = 'Enter at least one profile detail.');
      return;
    }
    if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await ref
        .read(sessionProvider.notifier)
        .updateProfile(
          name: name.isEmpty ? null : name,
          email: email.isEmpty ? null : email,
          dept: dept.isEmpty ? null : dept,
          level: level.isEmpty ? null : level,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RoostSpacing.xl,
        RoostSpacing.lg,
        RoostSpacing.xl,
        RoostSpacing.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full name'),
            RoostTextField(
              controller: _name,
              hint: 'Your full name',
              icon: PhosphorIcons.user(),
              autofocus: true,
            ),
            const SizedBox(height: RoostSpacing.md),
            _label('Email address'),
            RoostTextField(
              controller: _email,
              hint: 'you@example.com',
              icon: PhosphorIcons.envelope(),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: RoostSpacing.md),
            _label('Department'),
            RoostTextField(
              controller: _dept,
              hint: 'Software Engineering',
              icon: PhosphorIcons.buildings(),
            ),
            const SizedBox(height: RoostSpacing.md),
            _label('Level'),
            RoostTextField(
              controller: _level,
              hint: '400 Level',
              icon: PhosphorIcons.graduationCap(),
              action: TextInputAction.done,
            ),
            const SizedBox(height: RoostSpacing.sm),
            Text(
              'Your registration number is your account identity and cannot be changed here.',
              style: TextStyle(
                fontSize: 12,
                color: RoostColors.textTertiary,
                height: 1.35,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: RoostSpacing.md),
              Text(
                _error!,
                style: TextStyle(fontSize: 12.5, color: RoostColors.negative),
              ),
            ],
            const SizedBox(height: RoostSpacing.xl),
            RoostButton(
              label: 'Save profile',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String label) => Padding(
    padding: const EdgeInsets.only(bottom: RoostSpacing.sm, left: 2),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: RoostColors.textSecondary,
      ),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, this.last = false});
  final IconData icon;
  final String label;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RoostSpacing.lg,
            vertical: RoostSpacing.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: RoostColors.textSecondary),
              const SizedBox(width: RoostSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                PhosphorIcons.caretRight(),
                size: 16,
                color: RoostColors.textTertiary,
              ),
            ],
          ),
        ),
        if (!last)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Divider(height: 1, color: RoostColors.borderSubtle),
          ),
      ],
    );
  }
}

class _AppearanceToggle extends ConsumerWidget {
  const _AppearanceToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(brightnessProvider);
    final isLight = brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: RoostColors.surface2,
        shape: const SmoothRectangleBorder(
          borderRadius: SmoothBorderRadius.all(
            SmoothRadius(cornerRadius: RoostRadius.md, cornerSmoothing: 0.6),
          ),
        ),
      ),
      child: Row(
        children: [
          _seg(ref, 'Light', PhosphorIcons.sun(), isLight, Brightness.light),
          _seg(ref, 'Dark', PhosphorIcons.moon(), !isLight, Brightness.dark),
        ],
      ),
    );
  }

  Widget _seg(
    WidgetRef ref,
    String label,
    IconData icon,
    bool selected,
    Brightness b,
  ) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(brightnessProvider.notifier).set(b),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: selected ? RoostColors.surface1 : Colors.transparent,
            shadows: selected ? RoostShadows.card : null,
            shape: const SmoothRectangleBorder(
              borderRadius: SmoothBorderRadius.all(
                SmoothRadius(
                  cornerRadius: RoostRadius.sm,
                  cornerSmoothing: 0.6,
                ),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? RoostColors.accent : RoostColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? RoostColors.textPrimary
                      : RoostColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
