import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/api/roost_api.dart';
import '../../core/config/app_config.dart';
import '../../core/demo/hostel_data.dart';
import '../../core/session/session_controller.dart';
import '../../core/theme/brightness_provider.dart';
import '../../core/theme/squircle_button.dart';
import '../../core/theme/surface_card.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/hostel_glyph.dart';
import '../../core/widgets/receipt_detail_row.dart';
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/wavy_sheet.dart';

/// My bookings + history (FR10). Tap a booking for its allocation slip; paid
/// bookings can be cancelled.
class ReservationsPage extends ConsumerWidget {
  const ReservationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(brightnessProvider);
    final reservations = ref.watch(reservationsProvider);
    final active = reservations
        .where((r) => r.status == RoostStatus.paid)
        .toList();
    final paidTotal = active.fold(0, (s, r) => s + r.fee);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RoostSpacing.xl,
              RoostSpacing.lg,
              RoostSpacing.xl,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My bookings',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  'Your reservations and history',
                  style: TextStyle(
                    fontSize: 14,
                    color: RoostColors.textTertiary,
                  ),
                ),
                const SizedBox(height: RoostSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(label: 'Active', value: '${active.length}'),
                    ),
                    const SizedBox(width: RoostSpacing.md),
                    Expanded(
                      child: _Stat(
                        label: 'Paid this session',
                        value: '₦${_short(paidTotal)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: RoostSpacing.lg),
          Expanded(
            child: reservations.isEmpty
                ? _empty(context)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      RoostSpacing.xl,
                      0,
                      RoostSpacing.xl,
                      RoostSpacing.xxl,
                    ),
                    itemCount: reservations.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: RoostSpacing.md),
                    itemBuilder: (ctx, i) => _ReservationCard(
                      reservation: reservations[i],
                      onTap: () => _showSheet(ctx, ref, reservations[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _short(int n) => n >= 1000
      ? '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k'
      : '$n';

  Widget _empty(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIcons.ticket(), size: 44, color: RoostColors.textTertiary),
        const SizedBox(height: RoostSpacing.md),
        Text(
          'No bookings yet',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: RoostColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Reserve a bed and it shows up here.',
          style: TextStyle(fontSize: 13, color: RoostColors.textTertiary),
        ),
        const SizedBox(height: RoostSpacing.lg),
        SizedBox(
          width: 200,
          child: RoostButton(
            label: 'Browse hostels',
            onPressed: () => context.go('/home?tab=0'),
          ),
        ),
      ],
    ),
  );

  Future<void> _showSheet(
    BuildContext context,
    WidgetRef ref,
    Reservation initial,
  ) async {
    final h = HostelData.byId(initial.hostelId);
    await showRoostWavySheet(
      context: context,
      headerGradient: initial.status == RoostStatus.paid
          ? RoostGradients.accentHeader
          : RoostGradients.graphiteHeader,
      headerForeground: initial.status == RoostStatus.paid
          ? RoostColors.onAccent
          : RoostColors.textPrimary,
      headerHeight: 150,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            initial.status == RoostStatus.paid
                ? PhosphorIcons.sealCheck(PhosphorIconsStyle.fill)
                : PhosphorIcons.clockCounterClockwise(),
            size: 34,
            color: initial.status == RoostStatus.paid
                ? RoostColors.onAccent
                : RoostColors.textPrimary,
          ),
          const SizedBox(height: RoostSpacing.sm),
          Text(
            h.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: initial.status == RoostStatus.paid
                  ? RoostColors.onAccent
                  : RoostColors.textPrimary,
            ),
          ),
        ],
      ),
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          var current = initial;
          var checking = false;

          Future<void> checkStatus() async {
            setSheetState(() => checking = true);
            final messenger = ScaffoldMessenger.of(context);
            final api = ref.read(roostApiProvider);
            try {
              final status = await api.paymentStatus(current.rrr);
              if (status == 'paid') {
                Reservation updated;
                try {
                  updated = await api.reservation(current.id);
                } catch (_) {
                  updated = current.copyWith(status: RoostStatus.paid);
                }
                ref.read(reservationsProvider.notifier).replace(updated);
                setSheetState(() => current = updated);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Payment confirmed — bed allocated!'),
                  ),
                );
              } else {
                // Not paid. Paystack's hosted-checkout verify has no real
                // "still in progress" signal — an untouched link and a truly
                // abandoned one report identically — so a manual check that
                // isn't a success is treated as decisive: release the bed
                // rather than leave it held with no path forward.
                final cancelled = await api.cancelReservation(current.id);
                ref.read(reservationsProvider.notifier).replace(cancelled);
                HostelData.markBedReleased(
                  hostelId: cancelled.hostelId,
                  roomId: cancelled.roomId,
                  bed: cancelled.bed,
                );
                setSheetState(() => current = cancelled);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Payment not completed — the reservation has been released.',
                    ),
                  ),
                );
              }
            } on ApiException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
            } catch (_) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Could not check status. Please try again.'),
                ),
              );
            } finally {
              setSheetState(() => checking = false);
            }
          }

          final paid = current.status == RoostStatus.paid;
          final pending =
              current.status == RoostStatus.pending ||
              current.status == RoostStatus.reserved;

          return Padding(
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
                Center(child: StatusPill(current.status)),
                const SizedBox(height: RoostSpacing.lg),
                ReceiptDetailRow(
                  label: 'Name',
                  value: ref.read(sessionProvider)?.displayName ?? '—',
                ),
                ReceiptDetailRow(
                  label: 'Department',
                  value: ref.read(sessionProvider)?.displayDept ?? '—',
                ),
                ReceiptDetailRow(
                  label: 'Level',
                  value: ref.read(sessionProvider)?.displayLevel ?? '—',
                ),
                ReceiptDetailRow(
                  label: 'Room',
                  value: 'Room ${current.roomIndex}',
                ),
                ReceiptDetailRow(label: 'Bed', value: 'Bed ${current.bed}'),
                ReceiptDetailRow(
                  label: 'Reference',
                  value: current.reference,
                  mono: true,
                ),
                ReceiptDetailRow(
                  label: 'Payment Reference',
                  value: current.rrr,
                  mono: true,
                ),
                ReceiptDetailRow(label: 'Amount', value: current.feeFull),
                ReceiptDetailRow(label: 'Date', value: current.date),
                const SizedBox(height: RoostSpacing.xl),
                if (paid)
                  RoostButton(
                    label: 'Cancel reservation',
                    variant: RoostButtonVariant.destructive,
                    onPressed: () => _cancel(context, ref, current),
                  )
                else if (pending) ...[
                  RoostButton(
                    label: checking ? 'Checking…' : 'Check payment status',
                    isLoading: checking,
                    onPressed: checking ? null : checkStatus,
                  ),
                  const SizedBox(height: RoostSpacing.md),
                  RoostButton(
                    label: 'Close',
                    variant: RoostButtonVariant.secondary,
                    onPressed: checking
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ] else
                  RoostButton(
                    label: 'Close',
                    variant: RoostButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Cancel a paid booking (frees the bed). Demo mode flips it locally; live
  /// mode calls the API and swaps in the server's updated reservation.
  Future<void> _cancel(
    BuildContext context,
    WidgetRef ref,
    Reservation r,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (AppConfig.useDemoData) {
        ref.read(reservationsProvider.notifier).markCancelled(r.reference);
        HostelData.markBedReleased(
          hostelId: r.hostelId,
          roomId: r.roomId,
          bed: r.bed,
        );
      } else {
        final updated = await ref
            .read(roostApiProvider)
            .cancelReservation(r.id);
        ref.read(reservationsProvider.notifier).replace(updated);
        HostelData.markBedReleased(
          hostelId: updated.hostelId,
          roomId: updated.roomId,
          bed: updated.bed,
        );
      }
      navigator.pop();
    } on ApiException catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not cancel. Please try again.')),
      );
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return RoostSurfaceCard(
      floating: true,
      padding: const EdgeInsets.all(RoostSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: RoostColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: RoostColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.reservation, required this.onTap});
  final Reservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = HostelData.byId(reservation.hostelId);
    return RoostSurfaceCard(
      floating: true,
      padding: const EdgeInsets.all(RoostSpacing.lg),
      onTap: onTap,
      child: Row(
        children: [
          HostelGlyph(
            code: h.code,
            size: 44,
            accent: reservation.status == RoostStatus.paid,
          ),
          const SizedBox(width: RoostSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  h.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Room ${reservation.roomIndex}  ·  Bed ${reservation.bed}',
                  style: TextStyle(
                    fontSize: 13,
                    color: RoostColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill(reservation.status),
              const SizedBox(height: 6),
              Text(
                reservation.date,
                style: TextStyle(fontSize: 11, color: RoostColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
