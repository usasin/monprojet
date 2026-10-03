const salesStages = <String, String>{
  'qualify': 'À qualifier',
  'qualified': 'Qualifiée',
  'proposal': 'Proposition envoyée',
  'negotiation': 'Négociation',
  'won': 'Contrat signé',
  'lost': 'Perdue',
};
const salesInterests = <String, String>{
  'cold': 'Froid',
  'warm': 'Tiède',
  'hot': 'Chaud',
};
const salesActions = <String, String>{
  '': 'Aucune',
  'call': 'Appeler',
  'visit': 'Visiter',
  'proposal': 'Envoyer une proposition',
  'followup': 'Relancer',
};

DateTime? salesDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value);
  try {
    return value.toDate() as DateTime;
  } catch (_) {
    return null;
  }
}

class SalesDeal {
  const SalesDeal({
    required this.id,
    required this.ownerUid,
    required this.ownerName,
    required this.prospectId,
    required this.prospectName,
    required this.title,
    required this.stage,
    required this.interest,
    this.amountCents,
    this.closedAt,
    this.nextActionAt,
    this.updatedAt,
    this.createdAt,
    this.signedAt,
    this.nextAction = '',
    this.offer = '',
    this.contractReference = '',
    this.lostReason = '',
    this.note = '',
    this.revision = 0,
  });
  final String id,
      ownerUid,
      ownerName,
      prospectId,
      prospectName,
      title,
      stage,
      interest;
  final String nextAction, offer, contractReference, lostReason, note;
  final int? amountCents;
  final int revision;
  final DateTime? closedAt, nextActionAt, updatedAt, createdAt, signedAt;
  bool get open => stage != 'won' && stage != 'lost';
  bool overdue(DateTime now) =>
      open && nextActionAt != null && nextActionAt!.isBefore(now);
  factory SalesDeal.fromMap(
    String id,
    String uid,
    String ownerName,
    Map<String, dynamic> d,
  ) =>
      SalesDeal(
        id: id,
        ownerUid: uid,
        ownerName: ownerName,
        prospectId: '${d['prospectId'] ?? ''}',
        prospectName: '${d['prospectName'] ?? 'Prospect'}',
        title: '${d['title'] ?? ''}',
        stage: '${d['stage'] ?? 'qualify'}',
        interest: '${d['interest'] ?? 'warm'}',
        amountCents: (d['amountCents'] as num?)?.toInt(),
        revision: (d['revision'] as num?)?.toInt() ?? 0,
        closedAt: salesDate(d['closedAt']),
        signedAt: salesDate(d['signedAt']),
        nextActionAt: salesDate(d['nextActionAt']),
        updatedAt: salesDate(d['updatedAt']),
        createdAt: salesDate(d['createdAt']),
        nextAction: '${d['nextAction'] ?? ''}',
        offer: '${d['offer'] ?? ''}',
        contractReference: '${d['contractReference'] ?? ''}',
        lostReason: '${d['lostReason'] ?? ''}',
        note: '${d['note'] ?? ''}',
      );
}

class SalesWindow {
  const SalesWindow(this.start, this.end);
  final DateTime start, end;
  bool contains(DateTime? date) =>
      date != null && !date.isBefore(start) && date.isBefore(end);
  factory SalesWindow.forPeriod(DateTime now, String period) {
    final day = DateTime(now.year, now.month, now.day);
    if (period == 'day')
      return SalesWindow(day, DateTime(now.year, now.month, now.day + 1));
    if (period == 'month')
      return SalesWindow(
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      );
    final monday = DateTime(day.year, day.month, day.day - day.weekday + 1);
    return SalesWindow(
      monday,
      DateTime(monday.year, monday.month, monday.day + 7),
    );
  }
}

class SalesTotals {
  SalesTotals(Iterable<SalesDeal> deals, SalesWindow window, DateTime now) {
    all = deals.toList();
    won = all
        .where((d) => d.stage == 'won' && window.contains(d.closedAt))
        .toList();
    lost = all
        .where((d) => d.stage == 'lost' && window.contains(d.closedAt))
        .toList();
    hot = all.where((d) => d.open && d.interest == 'hot').toList();
    overdue = all.where((d) => d.overdue(now)).toList()
      ..sort((a, b) => a.nextActionAt!.compareTo(b.nextActionAt!));
    unsigned = all
        .where((d) => d.open && d.interest == 'hot' && d.nextActionAt == null)
        .toList();
    stagnant = all
        .where(
          (d) =>
              d.open &&
              d.updatedAt != null &&
              now.difference(d.updatedAt!).inDays >= 14,
        )
        .toList();
  }
  late final List<SalesDeal> all, won, lost, hot, overdue, unsigned, stagnant;
  int get signedCents => won.fold(0, (n, d) => n + (d.amountCents ?? 0));
  int get missingAmounts => won.where((d) => d.amountCents == null).length;
  double? get winRate => won.length + lost.length == 0
      ? null
      : won.length / (won.length + lost.length);
  int get openCents =>
      all.where((d) => d.open).fold(0, (n, d) => n + (d.amountCents ?? 0));
}

/// Integer cents avoid floating point accumulation. Null means not specified, zero is valid.
int? parseSalesAmount(String input) {
  final value = input
      .trim()
      .replaceAll(' ', '')
      .replaceAll('\u00a0', '')
      .replaceAll(',', '.');
  if (value.isEmpty) return null;
  if (!RegExp(r'^\d{1,9}(\.\d{1,2})?$').hasMatch(value))
    throw const FormatException('Montant positif, avec 2 décimales maximum.');
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
}
