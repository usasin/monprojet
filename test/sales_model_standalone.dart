import '../lib/sales/sales_model.dart';
void main() {
  var checks = 0;
  void check(bool ok, String label) { if (!ok) throw StateError(label); checks++; }
  final now = DateTime(2026, 10, 2, 12);
  final window = SalesWindow.forPeriod(now, 'week');
  check(window.start == DateTime(2026, 9, 28), 'Monday starts weekly period');
  check(window.end == DateTime(2026, 10, 5), 'Sunday excluded upper bound');
  SalesDeal deal(String id, String stage, {int? cents, DateTime? closed, DateTime? due, String interest='hot'}) => SalesDeal(id:id,ownerUid:'rep',ownerName:'Rep',prospectId:'p',prospectName:'Client',title:'Projet',stage:stage,interest:interest,amountCents:cents,closedAt:closed,nextActionAt:due);
  final deals = [deal('w1','won',cents:1999,closed:now),deal('w2','won',closed:now),deal('l','lost',closed:now),deal('o','negotiation',cents:500000,due:DateTime(2026,10,1)),deal('outside','won',cents:100,closed:window.end)];
  final totals=SalesTotals(deals,window,now);
  check(totals.won.length==2,'Won only within selected period');
  check(totals.winRate==2/3,'Open opportunities excluded from win rate');
  check(totals.signedCents==1999,'Missing amount is not invented');
  check(totals.missingAmounts==1,'Missing amount counted');
  check(totals.hot.length==1,'Only open deals in hot count');
  check(totals.overdue.length==1,'Only open overdue actions');
  check(SalesTotals([],window,now).winRate==null,'No closed deals means undefined rate');
  check(parseSalesAmount('19,99')==1999,'French decimal exact cents');
  check(parseSalesAmount('1 234.5')==123450,'Grouped amount');
  check(parseSalesAmount('')==null,'Unspecified amount');
  check(parseSalesAmount('0')==0,'Zero amount remains valid');
  for (final text in ['-1','12.999','NaN']) { var threw=false; try { parseSalesAmount(text); } on FormatException { threw=true; } check(threw,'Reject malformed amount $text'); }
  final month=SalesWindow.forPeriod(DateTime(2026,12,31),'month');
  check(month.end==DateTime(2027,1,1),'Year boundary');
  print('$checks sales model checks passed');
}
