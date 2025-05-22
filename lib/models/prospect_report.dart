// lib/models/prospect_report.dart

class ProspectReport {
  final String id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String category;

  final String status;
  final String note;
  final DateTime? nextVisit;
  final String phone;
  final String email;
  final String role;

  ProspectReport({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.category,
    required this.status,
    required this.note,
    required this.nextVisit,
    required this.phone,
    required this.email,
    required this.role,
  });
}
