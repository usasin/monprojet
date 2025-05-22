import 'package:cloud_firestore/cloud_firestore.dart';

class Prospect {
  /* ─────────── Champs obligatoires ─────────── */
  final String id;
  final String name;
  final String address;
  final String category;
  final double lat;
  final double lng;

  /* ─────────── Champs du reporting ─────────── */
  final String? phone;
  final String? email;
  final String? status;
  final String? role;
  final String? note;
  final DateTime? prochaineVisite;
  final DateTime? finishedAt;

  Prospect({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.lat,
    required this.lng,
    this.phone,
    this.email,
    this.status,
    this.role,
    this.note,
    this.prochaineVisite,
    this.finishedAt,
  });

  /* ───────────────────── Factory ───────────────────── */

  /// Construit un Prospect à partir d’une map Firestore.
  factory Prospect.fromFirestore(Map<String, dynamic> d, String id) {
    DateTime? _dt(dynamic v) => v == null ? null : (v as Timestamp).toDate();

    return Prospect(
      id      : id,
      name    : d['name']     ?? '',
      address : d['address']  ?? '',
      category: d['category'] ?? '',
      lat     : (d['lat'] as num).toDouble(),
      lng     : (d['lng'] as num).toDouble(),

      phone   : d['phone'],
      email   : d['email'],
      status  : d['status'],
      role    : d['role'],
      note    : d['note'],
      prochaineVisite : _dt(d['prochaineVisite'] ?? d['nextVisit']),
      finishedAt      : _dt(d['finishedAt']),
    );
  }

  /* ───────────────────── sérialisation ───────────────────── */

  Map<String, dynamic> toJson() => {
    'name'    : name,
    'address' : address,
    'category': category,
    'lat'     : lat,
    'lng'     : lng,
    if (phone          != null) 'phone'           : phone,
    if (email          != null) 'email'           : email,
    if (status         != null) 'status'          : status,
    if (role           != null) 'role'            : role,
    if (note           != null) 'note'            : note,
    if (prochaineVisite != null) 'prochaineVisite': prochaineVisite,
    if (finishedAt      != null) 'finishedAt'     : finishedAt,
  };
}
