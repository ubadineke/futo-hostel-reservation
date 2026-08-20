import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../widgets/status_pill.dart';

/// The app's data models + the in-memory reservation state.
///
/// The same model classes serve both modes: in **demo** mode they are filled
/// from the static [HostelData.hostels] below; in **live** mode the session
/// bootstrap hydrates them from the backend via `fromJson` (see
/// core/session/session_controller.dart). Values here are representative for
/// the FUTO demo (see REQUIREMENTS.md §4/§9).

enum Gender { male, female, mixed, postgrad }

extension GenderLabel on Gender {
  String get label => switch (this) {
    Gender.male => 'Male',
    Gender.female => 'Female',
    Gender.mixed => 'Mixed',
    Gender.postgrad => 'Postgraduate',
  };
}

// ---- JSON parse helpers (shared by the fromJson factories) ----

Gender _genderFrom(String? s) => switch (s) {
  'male' => Gender.male,
  'female' => Gender.female,
  'postgrad' => Gender.postgrad,
  _ => Gender.mixed,
};

RoostStatus? _statusFrom(String? s) => switch (s) {
  'available' => RoostStatus.available,
  'limited' => RoostStatus.limited,
  'full' => RoostStatus.full,
  _ => null,
};

RoostStatus _resStatusFrom(String? s) => switch (s) {
  'paid' => RoostStatus.paid,
  'reserved' => RoostStatus.reserved,
  'cancelled' => RoostStatus.cancelled,
  _ => RoostStatus.pending,
};

const List<String> _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
String _fmtDate(DateTime d) => '${_kMonths[d.month - 1]} ${d.day}, ${d.year}';
String _fmtIso(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso);
  return d == null ? iso : _fmtDate(d.toLocal());
}

/// A single real physical room within a hostel — "Room 1", "Room 2", ... All
/// rooms in a hostel share that hostel's [Hostel.capacity]; there's no
/// per-room size. [occupiedBeds] are bed numbers (1..bedsTotal) taken within
/// *this* room only. [bedsAvailable] is mutable so reserving a bed decrements
/// live availability (FR7) for the rest of the session.
class Room {
  Room({
    required this.id,
    required this.hostelId,
    required this.index,
    required this.bedsTotal,
    required this.occupiedBeds,
    int? bedsAvailable,
  }) : bedsAvailable = bedsAvailable ?? (bedsTotal - occupiedBeds.length);

  final String id;
  final String hostelId;
  final int index;
  final int bedsTotal;
  final List<int> occupiedBeds;
  int bedsAvailable;

  bool isTaken(int bed) => occupiedBeds.contains(bed);

  factory Room.fromJson(Map<String, dynamic> j) {
    final occupied = ((j['occupiedBeds'] as List?) ?? const [])
        .map((e) => int.tryParse(e.toString()) ?? -1)
        .where((n) => n > 0)
        .toList();
    return Room(
      id: (j['id'] ?? '').toString(),
      hostelId: (j['hostelId'] ?? '').toString(),
      index: (j['index'] as num?)?.toInt() ?? 1,
      bedsTotal: (j['bedsTotal'] as num?)?.toInt() ?? 0,
      occupiedBeds: occupied,
      bedsAvailable: (j['bedsAvailable'] as num?)?.toInt(),
    );
  }
}

class Hostel {
  Hostel({
    required this.id,
    required this.name,
    required this.code,
    required this.funder,
    required this.gender,
    required this.price,
    required this.capacity,
    required this.roomSize,
    required this.blurb,
    required this.lat,
    required this.lng,
    required this.coverA,
    required this.coverB,
    required this.rooms,
    int? bedsAvailableOverride,
    int? bedsTotalOverride,
    RoostStatus? statusOverride,
  }) : _bedsAvailableOverride = bedsAvailableOverride,
       _bedsTotalOverride = bedsTotalOverride,
       _statusOverride = statusOverride;

  final String id, name, code, funder, roomSize, blurb;
  final Gender gender;
  final int price;
  final int capacity; // beds per room — the same for every room in this hostel
  final double lat, lng;
  final int coverA, coverB; // cover gradient (ARGB)
  final List<Room> rooms;

  // Server aggregates, used only when [rooms] is empty (e.g. the list endpoint,
  // or a detail fetch that failed). When rooms are present we compute from them
  // so a local reserve decrement reflects immediately.
  final int? _bedsAvailableOverride, _bedsTotalOverride;
  final RoostStatus? _statusOverride;

  int get bedsAvailable => rooms.isNotEmpty
      ? rooms.fold(0, (s, r) => s + r.bedsAvailable)
      : (_bedsAvailableOverride ?? 0);
  int get bedsTotal => rooms.isNotEmpty
      ? rooms.fold(0, (s, r) => s + r.bedsTotal)
      : (_bedsTotalOverride ?? 0);

  RoostStatus get status {
    if (rooms.isEmpty && _statusOverride != null) return _statusOverride;
    final a = bedsAvailable;
    return a == 0
        ? RoostStatus.full
        : a <= 6
        ? RoostStatus.limited
        : RoostStatus.available;
  }

  String get priceLabel =>
      '₦${(price / 1000).toStringAsFixed(price % 1000 == 0 ? 0 : 1)}k';
  String get priceFull =>
      '₦${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  factory Hostel.fromJson(Map<String, dynamic> j) {
    final rooms =
        (j['rooms'] as List?)
            ?.map((e) => Room.fromJson(e as Map<String, dynamic>))
            .toList() ??
        <Room>[];
    return Hostel(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      code: (j['code'] ?? '').toString(),
      funder: (j['funder'] ?? '').toString(),
      gender: _genderFrom(j['gender']?.toString()),
      price: (j['price'] as num?)?.toInt() ?? 0,
      capacity: (j['capacity'] as num?)?.toInt() ?? 0,
      roomSize: (j['roomSize'] ?? '').toString(),
      blurb: (j['blurb'] ?? '').toString(),
      lat: (j['lat'] as num?)?.toDouble() ?? 0,
      lng: (j['lng'] as num?)?.toDouble() ?? 0,
      coverA: (j['coverA'] as num?)?.toInt() ?? 0xFF1E3A8A,
      coverB: (j['coverB'] as num?)?.toInt() ?? 0xFF2563EB,
      rooms: rooms,
      bedsAvailableOverride: (j['bedsAvailable'] as num?)?.toInt(),
      bedsTotalOverride: (j['bedsTotal'] as num?)?.toInt(),
      statusOverride: _statusFrom(j['status']?.toString()),
    );
  }
}

class Reservation {
  Reservation({
    this.id = '',
    required this.reference,
    required this.rrr,
    required this.hostelId,
    this.roomId = '',
    required this.roomIndex,
    required this.bed,
    required this.fee,
    required this.status,
    required this.date,
  });

  final String id, reference, rrr, hostelId, roomId, date;
  final int roomIndex, bed, fee;
  final RoostStatus status;

  Reservation copyWith({RoostStatus? status}) => Reservation(
    id: id,
    reference: reference,
    rrr: rrr,
    hostelId: hostelId,
    roomId: roomId,
    roomIndex: roomIndex,
    bed: bed,
    fee: fee,
    status: status ?? this.status,
    date: date,
  );

  String get feeFull =>
      '₦${fee.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  factory Reservation.fromJson(Map<String, dynamic> j) => Reservation(
    id: (j['id'] ?? '').toString(),
    reference: (j['reference'] ?? '').toString(),
    rrr: (j['rrr'] ?? '').toString(),
    hostelId: (j['hostelId'] ?? '').toString(),
    roomId: (j['roomId'] ?? '').toString(),
    roomIndex: (j['roomIndex'] as num?)?.toInt() ?? 0,
    bed: (j['bed'] as num?)?.toInt() ?? 0,
    fee: (j['fee'] as num?)?.toInt() ?? 0,
    status: _resStatusFrom(j['status']?.toString()),
    date: _fmtIso(j['createdAt']?.toString()),
  );
}

/// The signed-in student. In demo mode this is [Student.demo]; in live mode it
/// comes from `/auth/login` | `/auth/register` | `/auth/me`. Fields are nullable
/// because a freshly registered account may not have a name/dept/level yet.
class Student {
  const Student({
    this.id,
    this.name,
    this.regNo,
    this.email,
    this.dept,
    this.level,
  });

  final String? id, name, regNo, email, dept, level;

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    id: j['id']?.toString(),
    name: j['name']?.toString(),
    regNo: j['regNo']?.toString(),
    email: j['email']?.toString(),
    dept: j['dept']?.toString(),
    level: j['level']?.toString(),
  );

  factory Student.demo() => const Student(
    id: 'demo',
    name: HostelData.studentName,
    regNo: HostelData.studentRegNo,
    email: HostelData.studentEmail,
    dept: HostelData.studentDept,
    level: HostelData.studentLevel,
  );

  String get displayName => (name != null && name!.trim().isNotEmpty)
      ? name!
      : (regNo ?? email?.split('@').first ?? 'Student');
  String get displayRegNo =>
      (regNo != null && regNo!.isNotEmpty) ? regNo! : (email ?? '');
  String get displayDept =>
      (dept != null && dept!.trim().isNotEmpty) ? dept! : '—';
  String get displayLevel =>
      (level != null && level!.trim().isNotEmpty) ? level! : '—';
  String get displayEmail =>
      (email != null && email!.isNotEmpty) ? email! : '—';
}

/// Generates demo-mode rooms the same way the backend seed does: fill the
/// lowest-indexed rooms (and lowest bed numbers within them) first, leaving
/// the rest free.
List<Room> _demoRooms(
  String hostelId,
  int capacity,
  int roomCount,
  int bedsAvailable,
) {
  final bedsTotal = capacity * roomCount;
  var remaining = bedsTotal - bedsAvailable;
  return [
    for (var index = 1; index <= roomCount; index++)
      Room(
        id: '$hostelId-r$index',
        hostelId: hostelId,
        index: index,
        bedsTotal: capacity,
        occupiedBeds: () {
          final occupiedHere = remaining.clamp(0, capacity);
          remaining -= occupiedHere;
          return [for (var b = 1; b <= occupiedHere; b++) b];
        }(),
      ),
  ];
}

class HostelData {
  HostelData._();

  // ---- signed-in student (demo fallback identity) ----
  static const String studentName = 'Chidi Okeke';
  static const String studentRegNo = '20211234567';
  static const String studentEmail = 'okeke.chidi.20211234567@futo.edu.ng';
  static const String studentDept = 'Software Engineering';
  static const String studentLevel = '400 Level';

  // ---- the eight FUTO hostels (representative demo values). Mutable: the live
  //      bootstrap replaces this with server data via [replaceHostels]. ----
  static List<Hostel> hostels = [
    Hostel(
      id: 'A',
      name: 'Hostel A',
      code: 'A',
      funder: 'School',
      gender: Gender.male,
      price: 100,
      capacity: 8,
      roomSize: '8 per room',
      lat: 5.3869,
      lng: 7.0341,
      coverA: 0xFF1E3A8A,
      coverB: 0xFF2563EB,
      blurb:
          'A male school block close to the lecture halls. Dense, lively, and the cheapest way to stay on campus.',
      rooms: _demoRooms('A', 8, 11, 12),
    ),
    Hostel(
      id: 'B',
      name: 'Hostel B',
      code: 'B',
      funder: 'School',
      gender: Gender.male,
      price: 42000,
      capacity: 8,
      roomSize: '8 per room',
      lat: 5.3872,
      lng: 7.0347,
      coverA: 0xFF312E81,
      coverB: 0xFF4F46E5,
      blurb: 'Male school block beside Hostel A. Filling fast for the session.',
      rooms: _demoRooms('B', 8, 12, 5),
    ),
    Hostel(
      id: 'C',
      name: 'Hostel C',
      code: 'C',
      funder: 'School',
      gender: Gender.female,
      price: 45000,
      capacity: 8,
      roomSize: '8 per room',
      lat: 5.3858,
      lng: 7.0359,
      coverA: 0xFF0F766E,
      coverB: 0xFF0EA5A4,
      blurb:
          'A female block near TETFund. Calmer rooms with a little more space.',
      rooms: _demoRooms('C', 8, 10, 13),
    ),
    Hostel(
      id: 'D',
      name: 'Hostel D',
      code: 'D',
      funder: 'School',
      gender: Gender.female,
      price: 45000,
      capacity: 8,
      roomSize: '8 per room',
      lat: 5.3855,
      lng: 7.0364,
      coverA: 0xFF155E75,
      coverB: 0xFF0891B2,
      blurb: 'Female school block. Only a few beds remain this session.',
      rooms: _demoRooms('D', 8, 8, 2),
    ),
    Hostel(
      id: 'E',
      name: 'Hostel E',
      code: 'E',
      funder: 'School',
      gender: Gender.male,
      price: 42000,
      capacity: 8,
      roomSize: '8 per room',
      lat: 5.3877,
      lng: 7.0338,
      coverA: 0xFF1E293B,
      coverB: 0xFF334155,
      blurb:
          'Male school block on the far side. Fully booked for now — check back later.',
      rooms: _demoRooms('E', 8, 8, 0),
    ),
    Hostel(
      id: 'TETFUND',
      name: 'TETFund Hostel',
      code: 'TF',
      funder: 'TETFund',
      gender: Gender.mixed,
      price: 90000,
      capacity: 4,
      roomSize: '4 per room',
      lat: 5.3851,
      lng: 7.0366,
      coverA: 0xFF1D4ED8,
      coverB: 0xFF3B82F6,
      blurb:
          'The newest, most comfortable block — four to a room, en-suite, mixed and floor-segregated.',
      rooms: _demoRooms('TETFUND', 4, 20, 8),
    ),
    Hostel(
      id: 'NDDC',
      name: 'NDDC Hostel',
      code: 'ND',
      funder: 'NDDC',
      gender: Gender.mixed,
      price: 62500,
      capacity: 4,
      roomSize: '4 per room',
      lat: 5.3848,
      lng: 7.0371,
      coverA: 0xFF134E4A,
      coverB: 0xFF0D9488,
      blurb:
          'Lower-density, two-storey block housing both genders by floor. Premium comfort for the price.',
      rooms: _demoRooms('NDDC', 4, 25, 10),
    ),
    Hostel(
      id: 'PG',
      name: 'PG Hostel',
      code: 'PG',
      funder: 'Postgraduate',
      gender: Gender.postgrad,
      price: 75000,
      capacity: 6,
      roomSize: '6 per room',
      lat: 5.3845,
      lng: 7.0331,
      coverA: 0xFF4C1D95,
      coverB: 0xFF6D28D9,
      blurb: 'Quiet quarters for postgraduate students, six to a room.',
      rooms: _demoRooms('PG', 6, 9, 7),
    ),
  ];

  /// Replace the in-memory hostels with the authoritative server response.
  /// An empty list is valid when the production catalog has not been seeded.
  static void replaceHostels(List<Hostel> list) {
    hostels = list;
  }

  /// Keep the in-memory map aligned with a reservation created by the API.
  /// The API may assign a different free bed than the student's preference, so
  /// callers must pass the reservation's returned bed number.
  static void markBedHeld({
    required String hostelId,
    required String roomId,
    required int bed,
  }) {
    final room = _room(hostelId: hostelId, roomId: roomId);
    if (room == null) return;
    if (!room.occupiedBeds.contains(bed)) {
      room.occupiedBeds.add(bed);
      room.occupiedBeds.sort();
    }
    _syncAvailability(room);
  }

  /// Restore a bed only after the server confirms the reservation is cancelled.
  static void markBedReleased({
    required String hostelId,
    required String roomId,
    required int bed,
  }) {
    final room = _room(hostelId: hostelId, roomId: roomId);
    if (room == null) return;
    room.occupiedBeds.remove(bed);
    _syncAvailability(room);
  }

  static Room? _room({required String hostelId, required String roomId}) {
    final hostel = byIdOrNull(hostelId);
    if (hostel == null) return null;
    for (final room in hostel.rooms) {
      if (room.id == roomId) return room;
    }
    return null;
  }

  static void _syncAvailability(Room room) {
    room.bedsAvailable = (room.bedsTotal - room.occupiedBeds.length)
        .clamp(0, room.bedsTotal)
        .toInt();
  }

  static Hostel? byIdOrNull(String id) {
    for (final h in hostels) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Never throws — returns a neutral placeholder if the id is unknown, so a
  /// reservation for a hostel not in the current list still renders.
  static Hostel byId(String id) => byIdOrNull(id) ?? _fallback(id);

  static Hostel _fallback(String id) => Hostel(
    id: id,
    name: id,
    code: id.length <= 2 ? id.toUpperCase() : id.substring(0, 2).toUpperCase(),
    funder: '',
    gender: Gender.mixed,
    price: 0,
    capacity: 0,
    roomSize: '',
    blurb: '',
    lat: 0,
    lng: 0,
    coverA: 0xFF1E3A8A,
    coverB: 0xFF2563EB,
    rooms: const [],
  );
}

// ---- reservations: the mutable app state, via a Riverpod Notifier ----
//
// This controller holds NO network logic (keeps the module graph one-way).
// Screens perform the API calls (via roostApiProvider) and feed the results in
// through [setAll] / [add] / [replace]; demo mode uses [reserveDemo] directly.

class ReservationsController extends Notifier<List<Reservation>> {
  @override
  List<Reservation> build() => AppConfig.useDemoData
      ? [
          // one past (cancelled) booking so demo history isn't empty
          Reservation(
            reference: 'RST-7F3A21',
            rrr: '270054118832',
            hostelId: 'NDDC',
            roomIndex: 1,
            bed: 2,
            fee: 62500,
            status: RoostStatus.cancelled,
            date: 'Sep 14, 2025',
          ),
        ]
      : <Reservation>[];

  bool get hasActive => state.any(
    (r) =>
        r.status == RoostStatus.paid ||
        r.status == RoostStatus.reserved ||
        r.status == RoostStatus.pending,
  );

  /// Load the student's reservations from the server (called on bootstrap).
  void setAll(List<Reservation> list) => state = list;

  /// Prepend a reservation (de-dupes by id when the server assigned one).
  void add(Reservation r) =>
      state = [r, ...state.where((x) => r.id.isEmpty || x.id != r.id)];

  /// Swap in an updated reservation (e.g. after cancel).
  void replace(Reservation r) => state = [
    for (final x in state)
      if ((r.id.isNotEmpty && x.id == r.id) || x.reference == r.reference)
        r
      else
        x,
  ];

  void markCancelled(String reference) => state = [
    for (final x in state)
      if (x.reference == reference)
        x.copyWith(status: RoostStatus.cancelled)
      else
        x,
  ];

  /// Demo-mode reserve: synthesise a paid booking in memory (no backend).
  Reservation reserveDemo({
    required Hostel hostel,
    required Room room,
    required int bed,
    required int fee,
  }) {
    HostelData.markBedHeld(hostelId: hostel.id, roomId: room.id, bed: bed);
    final stamp = DateTime.now();
    final res = Reservation(
      reference:
          'RST-${stamp.millisecondsSinceEpoch.toRadixString(16).substring(4).toUpperCase()}',
      rrr: (stamp.millisecondsSinceEpoch % 1000000000000).toString().padLeft(
        12,
        '0',
      ),
      hostelId: hostel.id,
      roomId: room.id,
      roomIndex: room.index,
      bed: bed,
      fee: fee,
      status: RoostStatus.paid,
      date: _fmtDate(stamp),
    );
    state = [res, ...state];
    return res;
  }
}

final reservationsProvider =
    NotifierProvider<ReservationsController, List<Reservation>>(
      ReservationsController.new,
    );
