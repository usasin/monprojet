import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'enterprise_repository.dart';
import 'enterprise_snapshot.dart';
import 'sales_insights.dart';
import 'sales_model.dart';
import 'sales_visuals.dart';
import 'enterprise_actions.dart';
import '../widgets/brand_background.dart';
import '../providers/org_provider.dart';
import 'package:provider/provider.dart';

const enterpriseProspectFilters = <String, String>{
  'all': 'Tous',
  'new': 'Nouveaux',
  'qualify': 'À qualifier',
  'hot': 'Chauds',
  'followup': 'À relancer',
  'won': 'Signés',
};

class EnterprisePortfolio extends StatefulWidget {
  const EnterprisePortfolio({
    super.key,
    required this.controller,
    this.initialFilter = 'all',
    this.embedded = false,
  });
  final EnterpriseController controller;
  final String initialFilter;
  final bool embedded;
  @override
  State<EnterprisePortfolio> createState() => _EnterprisePortfolioState();
}

class _EnterprisePortfolioState extends State<EnterprisePortfolio> {
  late String filter = widget.initialFilter;
  String search = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final view = widget.controller.view;
          Widget body;
          if (widget.controller.loading || view == null) {
            body = widget.controller.error == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: TextButton(
                      onPressed: widget.controller.refresh,
                      child: Text(widget.controller.error!),
                    ),
                  );
          } else {
            final rows = view.prospectsFor(filter).where((p) {
              final prospect = p.prospect;
              return '${prospect.name} ${prospect.address} ${prospect.category} ${prospect.phone ?? ''} ${prospect.email ?? ''}'
                  .toLowerCase()
                  .contains(search.toLowerCase());
            }).toList()
              ..sort(
                (a, b) => a.prospect.name.toLowerCase().compareTo(
                      b.prospect.name.toLowerCase(),
                    ),
              );
            body = Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un prospect',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(18)),
                      ),
                    ),
                    onChanged: (v) => setState(() => search = v),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: enterpriseProspectFilters.entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                e.value,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: filter == e.key,
                              onSelected: (_) => setState(() => filter = e.key),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '${rows.length} prospects · ${EnterpriseController.scopeOptions(view.snapshot)[view.scope]}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: rows.isEmpty
                      ? const Center(
                          child: Text('Aucun prospect correspondant.'))
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            final row = rows[index];
                            final p = row.prospect;
                            final owners = view
                                .dealsFor(p.id)
                                .map((d) => d.ownerName)
                                .toSet();
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 5,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                leading: CircleAvatar(
                                  child: Text(
                                    p.name.isEmpty
                                        ? 'P'
                                        : p.name.substring(0, 1).toUpperCase(),
                                  ),
                                ),
                                title: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${p.address}${owners.isEmpty ? '' : '\nSuivi : ${owners.join(', ')}'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute<bool>(
                                      builder: (_) => EnterpriseProspectDetail(
                                        orgId:
                                            widget.controller.repository.orgId,
                                        row: row,
                                        view: view,
                                      ),
                                    ),
                                  );
                                  await widget.controller.refresh();
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          }
          return widget.embedded
              ? body
              : Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  appBar: AppBar(
                    title: Text(
                      enterpriseProspectFilters[filter] == 'Tous'
                          ? 'Prospects de l’entreprise'
                          : 'Prospects · ${enterpriseProspectFilters[filter]}',
                    ),
                  ),
                  body: BrandBackground(animate: false, child: body),
                );
        },
      );
}

class EnterpriseProspectDetail extends StatelessWidget {
  const EnterpriseProspectDetail({
    super.key,
    required this.orgId,
    required this.row,
    required this.view,
  });
  final String orgId;
  final EnterpriseProspect row;
  final EnterpriseView view;
  @override
  Widget build(BuildContext context) {
    final p = row.prospect;
    final deals = view.dealsFor(p.id);
    final org = context.watch<OrgProvider>();
    final canDelete = org.isOwner && org.orgId == orgId;
    return BrandBackground(
      animate: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Fiche prospect'),
          backgroundColor: Colors.transparent,
          actions: [
            if (canDelete)
              IconButton(
                tooltip: 'Supprimer le prospect',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  if (await EnterpriseActions.remove(
                        context,
                        orgId,
                        'prospect',
                        p.id,
                      ) &&
                      context.mounted) Navigator.pop(context, true);
                },
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            VisualHero(
              title: p.name,
              subtitle: p.address,
              badges: [
                if (p.category.isNotEmpty) SalesBadge(p.category),
                if ((p.role ?? '').isNotEmpty) SalesBadge(p.role!),
                SalesBadge(
                  '${deals.length} opportunité${deals.length > 1 ? 's' : ''}',
                ),
              ],
            ),
            const SizedBox(height: 14),
            VisualSection(
              title: 'Contact',
              icon: Icons.contact_page_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if ((p.phone ?? '').isNotEmpty)
                    _ContactLine(
                      icon: Icons.phone_outlined,
                      label: p.phone!,
                      onTap: () => launchUrl(Uri(scheme: 'tel', path: p.phone)),
                    ),
                  if ((p.email ?? '').isNotEmpty)
                    _ContactLine(
                      icon: Icons.mail_outline,
                      label: p.email!,
                      onTap: () =>
                          launchUrl(Uri(scheme: 'mailto', path: p.email)),
                    ),
                  if ((p.website ?? '').isNotEmpty)
                    _ContactLine(
                        icon: Icons.language,
                        label: p.website!,
                        onTap: () {
                          final uri = Uri.tryParse(p.website!.startsWith('http')
                              ? p.website!
                              : 'https://${p.website!}');
                          if (uri != null &&
                              ['http', 'https'].contains(uri.scheme))
                            launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                        }),
                  if ((p.openingHours ?? '').isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(p.openingHours!,
                            style: const TextStyle(fontSize: 12))),
                  if (p.address.isNotEmpty)
                    _ContactLine(
                      icon: Icons.place_outlined,
                      label: p.address,
                      onTap: () => launchUrl(
                        Uri.https('www.google.com', '/maps/search/', {
                          'api': '1',
                          'query': p.address,
                        }),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  if ((p.phone ?? '').isEmpty && (p.email ?? '').isEmpty)
                    const Text(
                      'Coordonnées à compléter.',
                      style: TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            VisualSection(
              title: 'Suivi commercial',
              icon: Icons.business_center_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (deals.isEmpty)
                    const Text(
                      'Aucun projet suivi pour le moment.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ...deals.map(
                    (d) => OpportunityCard(
                      deal: d,
                      showRevenue: org.displaySettings.showRevenue,
                      onTap: () async {
                        final changed = await openSalesDeal(
                          context,
                          orgId,
                          d,
                          readOnly: true,
                        );
                        if (changed == true && context.mounted)
                          Navigator.pop(context, true);
                      },
                    ),
                  ),
                ],
              ),
            ),
            if ((p.note ?? '').isNotEmpty) ...[
              const SizedBox(height: 14),
              VisualSection(
                title: 'Notes',
                icon: Icons.notes_outlined,
                child: Text(p.note!, style: const TextStyle(fontSize: 14)),
              ),
            ],
            const SizedBox(height: 14),
            VisualSection(
              title: 'Repères',
              icon: Icons.info_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (row.createdBy.isNotEmpty)
                    Text(
                      'Ajouté par ${view.nameFor(row.createdBy)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (row.createdAt != null)
                    Text(
                      DateFormat('dd MMM yyyy', 'fr_FR').format(row.createdAt!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (row.createdBy.isEmpty && row.createdAt == null)
                    const Text(
                      'Fiche du répertoire partagé.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 21),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 14))),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      );
}

Future<void> showEnterpriseDeals(
  BuildContext context,
  String orgId,
  String title,
  List<SalesDeal> deals,
) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: deals.isEmpty
              ? const Center(child: Text('Aucune affaire correspondante.'))
              : ListView.builder(
                  itemCount: deals.length,
                  itemBuilder: (context, i) {
                    final d = deals[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OpportunityCard(
                        deal: d,
                        showRevenue: context
                            .read<OrgProvider>()
                            .displaySettings
                            .showRevenue,
                        onTap: () async {
                          final changed = await openSalesDeal(
                            context,
                            orgId,
                            d,
                            readOnly: true,
                          );
                          if (changed == true && context.mounted)
                            Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );

Future<void> showEnterpriseRecords(
  BuildContext context,
  String title,
  List<EnterpriseRecord> records,
  EnterpriseView view, {
  required String kind,
  required String orgId,
}) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: records.isEmpty
              ? const Center(child: Text('Aucun élément correspondant.'))
              : ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, i) {
                    final r = records[i];
                    final label = kind == 'invite'
                        ? '${r.data['email'] ?? r.id}'
                        : kind == 'appointment'
                            ? '${r.data['title'] ?? 'RDV'}'
                            : 'Tournée · ${r.date == null ? r.id : DateFormat('dd/MM/yyyy').format(r.date!)}';
                    return ListTile(
                      title: Text(label),
                      subtitle: Text(
                        kind == 'invite'
                            ? '${r.data['role'] ?? 'REP'} · expire le ${DateFormat('dd/MM/yyyy').format(salesDate(r.data['expiresAt'])!)}'
                            : '${view.nameFor(r.ownerUid)}${kind == 'plan' ? '\n${r.completedVisits} / ${r.prospectIds.length} visites réalisées' : r.date == null ? '' : '\n${DateFormat('dd/MM HH:mm').format(r.date!)}'}',
                      ),
                      trailing: kind == 'invite' &&
                              context.read<OrgProvider>().isOwner
                          ? IconButton(
                              tooltip: 'Supprimer l’invitation',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                if (await EnterpriseActions.remove(
                                      context,
                                      orgId,
                                      'invite',
                                      r.id,
                                    ) &&
                                    context.mounted) Navigator.pop(context);
                              },
                            )
                          : kind == 'plan'
                              ? const Icon(Icons.chevron_right)
                              : null,
                      onTap: kind != 'plan'
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(title: Text(label)),
                                    body: ListView(
                                      children: [
                                        for (final id in r.prospectIds)
                                          Builder(
                                            builder: (context) {
                                              final row = view
                                                  .snapshot.prospects
                                                  .where((p) =>
                                                      p.prospect.id == id)
                                                  .firstOrNull;
                                              final report =
                                                  Map<String, dynamic>.from(
                                                r.data['reports'] ?? const {},
                                              )[id];
                                              return ListTile(
                                                title: Text(
                                                  row?.prospect.name ??
                                                      'Prospect retiré du répertoire',
                                                ),
                                                subtitle: Text(
                                                  report is Map
                                                      ? '${report['status'] ?? 'À renseigner'}${report['note'] == null ? '' : '\n${report['note']}'}'
                                                      : 'À renseigner',
                                                ),
                                                onTap: row == null
                                                    ? null
                                                    : () => Navigator.push(
                                                          context,
                                                          MaterialPageRoute<
                                                              void>(
                                                            builder: (_) =>
                                                                EnterpriseProspectDetail(
                                                              orgId: orgId,
                                                              row: row,
                                                              view: view,
                                                            ),
                                                          ),
                                                        ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                    );
                  },
                ),
        ),
      ),
    );
