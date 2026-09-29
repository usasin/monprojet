import 'package:cloud_firestore/cloud_firestore.dart';

class Prospect {
  final String id;
  final String name;
  final String address;
  final String category;
  final double lat;
  final double lng;

  final String? phone;
  final String? email;
  final String? website;
  final String? openingHours;
  final String? instagram;
  final String? facebook;
  final String? linkedin;
  final String? status;
  final String? role;
  final String? note;
  final DateTime? prochaineVisite;
  final DateTime? finishedAt;

  /// Métadonnées utilisées par le planificateur intelligent.
  /// 1 = faible, 3 = normale, 5 = urgente.
  final int priority;
  final int visitDurationMinutes;
  final DateTime? appointmentAt;

  Prospect({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.lat,
    required this.lng,
    this.phone,
    this.email,
    this.website,
    this.openingHours,
    this.instagram,
    this.facebook,
    this.linkedin,
    this.status,
    this.role,
    this.note,
    this.prochaineVisite,
    this.finishedAt,
    this.priority = 3,
    this.visitDurationMinutes = 30,
    this.appointmentAt,
  });

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory Prospect.fromFirestore(Map<String, dynamic> data, String id) {
    return Prospect(
      id: id,
      name: (data['name'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      lat: (data['lat'] as num?)?.toDouble() ?? 0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0,
      phone: data['phone']?.toString(),
      email: data['email']?.toString(),
      website: data['website']?.toString(),
      openingHours: data['openingHours']?.toString(),
      instagram: data['instagram']?.toString(),
      facebook: data['facebook']?.toString(),
      linkedin: data['linkedin']?.toString(),
      status: data['status']?.toString(),
      role: data['role']?.toString(),
      note: data['note']?.toString(),
      prochaineVisite: _date(data['prochaineVisite'] ?? data['nextVisit']),
      finishedAt: _date(data['finishedAt']),
      priority: ((data['priority'] as num?)?.toInt() ?? 3).clamp(1, 5).toInt(),
      visitDurationMinutes:
          ((data['visitDurationMinutes'] as num?)?.toInt() ?? 30).clamp(10, 240).toInt(),
      appointmentAt: _date(data['appointmentAt']),
    );
  }

  Prospect copyWith({
    String? id,
    String? name,
    String? address,
    String? category,
    double? lat,
    double? lng,
    String? phone,
    String? email,
    String? website,
    String? openingHours,
    String? instagram,
    String? facebook,
    String? linkedin,
    String? status,
    String? role,
    String? note,
    DateTime? prochaineVisite,
    DateTime? finishedAt,
    int? priority,
    int? visitDurationMinutes,
    DateTime? appointmentAt,
    bool clearAppointment = false,
  }) {
    return Prospect(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      category: category ?? this.category,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      openingHours: openingHours ?? this.openingHours,
      instagram: instagram ?? this.instagram,
      facebook: facebook ?? this.facebook,
      linkedin: linkedin ?? this.linkedin,
      status: status ?? this.status,
      role: role ?? this.role,
      note: note ?? this.note,
      prochaineVisite: prochaineVisite ?? this.prochaineVisite,
      finishedAt: finishedAt ?? this.finishedAt,
      priority: priority ?? this.priority,
      visitDurationMinutes: visitDurationMinutes ?? this.visitDurationMinutes,
      appointmentAt: clearAppointment ? null : (appointmentAt ?? this.appointmentAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'category': category,
        'lat': lat,
        'lng': lng,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (website != null && website!.isNotEmpty) 'website': website,
        if (openingHours != null && openingHours!.isNotEmpty)
          'openingHours': openingHours,
        if (instagram != null && instagram!.isNotEmpty) 'instagram': instagram,
        if (facebook != null && facebook!.isNotEmpty) 'facebook': facebook,
        if (linkedin != null && linkedin!.isNotEmpty) 'linkedin': linkedin,
        if (status != null) 'status': status,
        if (role != null) 'role': role,
        if (note != null) 'note': note,
        if (prochaineVisite != null) 'prochaineVisite': prochaineVisite,
        if (finishedAt != null) 'finishedAt': finishedAt,
        'priority': priority,
        'visitDurationMinutes': visitDurationMinutes,
        if (appointmentAt != null) 'appointmentAt': appointmentAt,
      };
}
