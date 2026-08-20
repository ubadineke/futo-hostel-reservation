import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../core/widgets/status_pill.dart';
import '../../core/widgets/receipt_detail_row.dart';
import '../../core/widgets/wavy_sheet.dart';
import 'payment_webview_page.dart';

/// Pick a room + bed, then pay via Paystack (sandbox) and get the allocation
/// receipt (FR7, FR8, FR9). Every room in a hostel is the same size, so
/// there's no separate "choose a room type" step — straight to real rooms.
class ReservePage extends ConsumerStatefulWidget {
  const ReservePage({super.key, required this.hostelId});
  final String hostelId;

  @override
  ConsumerState<ReservePage> createState() => _ReservePageState();
}

class _ReservePageState extends ConsumerState<ReservePage> {
  int? _roomIdx; // index into h.rooms
  int? _bed; // local bed number (1..capacity)
  bool _paying = false;

  /// Reserve → open Paystack checkout in-app → poll for confirmation → receipt.
  /// Demo mode skips straight to a synthesised paid booking.
  Future<void> _pay(Hostel h, Room room, int bed) async {
    setState(() => _paying = true);
    HapticFeedback.mediumImpact();
    try {
      if (AppConfig.useDemoData) {
        await Future.delayed(
          const Duration(milliseconds: 1600),
        ); // mock gateway
        final res = ref
            .read(reservationsProvider.notifier)
            .reserveDemo(hostel: h, room: room, bed: bed, fee: h.price);
        if (!mounted) return;
        await _showReceipt(h, res);
        return;
      }

      final api = ref.read(roostApiProvider);
      final created = await api.createReservation(
        hostelId: h.id,
        roomId: room.id,
        bed: bed,
      );
      HostelData.markBedHeld(
        hostelId: created.reservation.hostelId,
        roomId: created.reservation.roomId,
        bed: created.reservation.bed,
      );
      ref.read(reservationsProvider.notifier).add(created.reservation);
      if (!mounted) return;

      // Full-screen push (not a sheet) — this is a real external checkout page,
      // it should read like leaving-and-returning, not a modal over the form.
      final finishedCheckout = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              PaymentWebViewPage(authorizationUrl: created.authorizationUrl),
        ),
      );
      if (!mounted) return;

      if (finishedCheckout != true) {
        // Backed out of checkout. Check live once — Paystack's hosted-checkout
        // verify only ever reports success/failed/abandoned (no true
        // "in-progress" state), so a definitive answer here is trustworthy:
        // if it somehow did go through despite the backout (callback
        // interception can miss it), keep the booking; otherwise release the
        // held bed instead of leaving it stuck with no path forward.
        await _resolveUnconfirmedCheckout(created.reservation, h);
        return;
      }

      final status = await _pollForConfirmation(created.reservation.rrr);
      if (!mounted) return;

      if (status == 'paid') {
        Reservation res;
        try {
          res = await api.reservation(
            created.reservation.id,
          ); // final allocation
        } catch (_) {
          res = created.reservation.copyWith(status: RoostStatus.paid);
        }
        ref.read(reservationsProvider.notifier).replace(res);
        await _showReceipt(h, res);
      } else if (status == 'failed') {
        ref
            .read(reservationsProvider.notifier)
            .markCancelled(created.reservation.reference);
        HostelData.markBedReleased(
          hostelId: created.reservation.hostelId,
          roomId: created.reservation.roomId,
          bed: created.reservation.bed,
        );
        _snack(
          'Payment was not successful. The bed has been released — you can try again.',
        );
      } else {
        _snack("Still waiting on confirmation — check your Bookings shortly.");
      }
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Payment could not be completed. Please try again.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Single live check after an explicit backout (not the bounded poll —
  /// there's no propagation delay to wait out here, just one definitive
  /// answer). Paid keeps the booking and shows the receipt; anything else
  /// releases the bed. Only a failure to even reach the server leaves the
  /// reservation untouched, since we don't want to cancel on an inconclusive
  /// check.
  Future<void> _resolveUnconfirmedCheckout(
    Reservation reservation,
    Hostel h,
  ) async {
    final api = ref.read(roostApiProvider);
    try {
      final status = await api.paymentStatus(reservation.rrr);
      if (status == 'paid') {
        Reservation res;
        try {
          res = await api.reservation(reservation.id);
        } catch (_) {
          res = reservation.copyWith(status: RoostStatus.paid);
        }
        ref.read(reservationsProvider.notifier).replace(res);
        if (!mounted) return;
        await _showReceipt(h, res);
        return;
      }
      final cancelled = await api.cancelReservation(reservation.id);
      ref.read(reservationsProvider.notifier).replace(cancelled);
      HostelData.markBedReleased(
        hostelId: cancelled.hostelId,
        roomId: cancelled.roomId,
        bed: cancelled.bed,
      );
      _snack(
        "Payment wasn't completed — your reservation was released. You can try again anytime.",
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not confirm payment status. Check Bookings to try again.');
    }
  }

  /// No webhook — the server checks Paystack live on each call. Bounded
  /// polling so a student who abandons checkout doesn't leave this spinning
  /// forever; "pending" after this just means check Bookings again shortly.
  Future<String> _pollForConfirmation(String rrr) async {
    final api = ref.read(roostApiProvider);
    const maxAttempts = 15;
    const interval = Duration(seconds: 2);
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final status = await api.paymentStatus(rrr);
        if (status == 'paid' || status == 'failed') return status;
      } catch (_) {
        // transient network hiccup — keep polling rather than giving up
      }
      await Future.delayed(interval);
    }
    return 'pending';
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showReceipt(Hostel h, Reservation res) async {
    final student = ref.read(sessionProvider);
    await showRoostWavySheet(
      context: context,
      dismissible: false,
      headerHeight: 158,
      header: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.sealCheck(PhosphorIconsStyle.fill),
            size: 40,
            color: RoostColors.onAccent,
          ),
          const SizedBox(height: RoostSpacing.sm),
          Text(
            'Reservation confirmed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: RoostColors.onAccent,
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
            ReceiptDetailRow(label: 'Name', value: student?.displayName ?? '—'),
            ReceiptDetailRow(label: 'Department', value: student?.displayDept ?? '—'),
            ReceiptDetailRow(label: 'Level', value: student?.displayLevel ?? '—'),
            ReceiptDetailRow(label: 'Hostel', value: h.name),
            ReceiptDetailRow(label: 'Room', value: 'Room ${res.roomIndex}'),
            ReceiptDetailRow(label: 'Bed', value: 'Bed ${res.bed}'),
            ReceiptDetailRow(
              label: 'Reference',
              value: res.reference,
              mono: true,
            ),
            ReceiptDetailRow(
              label: 'Payment Reference',
              value: res.rrr,
              mono: true,
            ),
            ReceiptDetailRow(
              label: 'Amount paid',
              value: res.feeFull,
              strong: true,
            ),
            const SizedBox(height: RoostSpacing.lg),
            Container(
              padding: const EdgeInsets.all(RoostSpacing.md),
              decoration: ShapeDecoration(
                color: RoostColors.accentSubtle,
                shape: const SmoothRectangleBorder(
                  borderRadius: SmoothBorderRadius.all(
                    SmoothRadius(
                      cornerRadius: RoostRadius.md,
                      cornerSmoothing: 0.6,
                    ),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    PhosphorIcons.info(),
                    size: 16,
                    color: RoostColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Show this allocation slip at the Student Affairs Unit to check in.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: RoostColors.accent,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RoostSpacing.xl),
            RoostButton(
              label: 'Done',
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home?tab=1');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brightnessProvider);
    final h = HostelData.byId(widget.hostelId);
    final room = _roomIdx == null ? null : h.rooms[_roomIdx!];
    final canPay = room != null && _bed != null && !_paying;

    return Scaffold(
      backgroundColor: RoostColors.surface0,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                RoostSpacing.md,
                RoostSpacing.sm,
                RoostSpacing.xl,
                RoostSpacing.sm,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        PhosphorIcons.caretLeft(),
                        size: 22,
                        color: RoostColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reserve a bed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: RoostColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${h.name} · ${h.roomSize}',
                        style: TextStyle(
                          fontSize: 13,
                          color: RoostColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                RoostSpacing.xl,
                RoostSpacing.lg,
                RoostSpacing.xl,
                RoostSpacing.xl,
              ),
              children: [
                Text(
                  'Pick a room & bed',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: RoostSpacing.md),
                for (var i = 0; i < h.rooms.length; i++) ...[
                  _RoomSection(
                    room: h.rooms[i],
                    selectedBed: _roomIdx == i ? _bed : null,
                    onPick: (bed) => setState(() {
                      _roomIdx = i;
                      _bed = bed;
                    }),
                  ),
                  const SizedBox(height: RoostSpacing.lg),
                ],
                const SizedBox(height: RoostSpacing.sm),
                _FeeSummary(hostel: h, roomIndex: room?.index, bed: _bed),
              ],
            ),
          ),
          _bottomBar(context, h, room, _bed, canPay),
        ],
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    Hostel h,
    Room? room,
    int? bed,
    bool canPay,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: RoostColors.surface1,
        border: Border(
          top: BorderSide(color: RoostColors.borderSubtle, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            RoostSpacing.xl,
            RoostSpacing.md,
            RoostSpacing.xl,
            RoostSpacing.md,
          ),
          child: RoostButton(
            label: _paying ? 'Processing…' : 'Pay ${h.priceFull}',
            icon: _paying
                ? null
                : PhosphorIcons.lockSimple(PhosphorIconsStyle.fill),
            isLoading: _paying,
            onPressed: canPay ? () => _pay(h, room!, bed!) : null,
          ),
        ),
      ),
    );
  }
}

/// One section per real physical room ("Room 1", "Room 2", ...) with its own
/// real occupancy grid.
class _RoomSection extends StatelessWidget {
  const _RoomSection({
    required this.room,
    required this.selectedBed,
    required this.onPick,
  });
  final Room room;
  final int? selectedBed;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final full = room.bedsAvailable == 0;
    return Opacity(
      opacity: full ? 0.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Room ${room.index}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: RoostColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                full ? 'Full' : '${room.bedsAvailable} open',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: full ? RoostColors.negative : RoostColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: RoostSpacing.sm),
          Wrap(
            spacing: RoostSpacing.md,
            runSpacing: RoostSpacing.md,
            children: [
              for (var bed = 1; bed <= room.bedsTotal; bed++)
                _BedTile(
                  bed: bed,
                  taken: room.isTaken(bed),
                  selected: selectedBed == bed,
                  onTap: () => onPick(bed),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BedTile extends StatelessWidget {
  const _BedTile({
    required this.bed,
    required this.taken,
    required this.selected,
    required this.onTap,
  });
  final int bed;
  final bool taken;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg, fg, border;
    if (taken) {
      bg = RoostColors.surface2;
      fg = RoostColors.textDisabled;
      border = RoostColors.borderSubtle;
    } else if (selected) {
      bg = RoostColors.accent;
      fg = RoostColors.onAccent;
      border = RoostColors.accent;
    } else {
      bg = RoostColors.surface1;
      fg = RoostColors.textPrimary;
      border = RoostColors.borderDefault;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: taken ? null : onTap,
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: bg,
          shape: SmoothRectangleBorder(
            side: BorderSide(color: border, width: selected ? 1.4 : 0.5),
            borderRadius: const SmoothBorderRadius.all(
              SmoothRadius(cornerRadius: RoostRadius.md, cornerSmoothing: 0.6),
            ),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.bed(), size: 18, color: fg),
            const SizedBox(height: 2),
            Text(
              '$bed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeeSummary extends StatelessWidget {
  const _FeeSummary({
    required this.hostel,
    required this.roomIndex,
    required this.bed,
  });
  final Hostel hostel;
  final int? roomIndex;
  final int? bed;

  @override
  Widget build(BuildContext context) {
    return RoostSurfaceCard(
      elevated: true,
      child: Column(
        children: [
          _line('Hostel', hostel.name),
          _line('Room', roomIndex == null ? '—' : 'Room $roomIndex'),
          _line('Bed', bed == null ? '—' : 'Bed $bed'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RoostSpacing.md),
            child: Divider(height: 1, color: RoostColors.borderSubtle),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: RoostColors.textSecondary,
                      ),
                    ),
                    Text(
                      'per session',
                      style: TextStyle(
                        fontSize: 11,
                        color: RoostColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RoostSpacing.md),
              Text(
                hostel.priceFull,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: RoostColors.accent,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _line(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(
          l,
          style: TextStyle(fontSize: 13.5, color: RoostColors.textTertiary),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            v,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
