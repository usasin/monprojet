import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';

class OrgActivityScreen extends StatelessWidget {
  static const routeName = '/org_activity';
  const OrgActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final orgId = org.orgId;
    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const LText(
            'Activité de l’équipe',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: orgId == null || !org.isOwner
            ? const Center(
                child: LText('Cette section est réservée aux administrateurs.'),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: OrgService(kAppId).activity(orgId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: LText('Chargement impossible : ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: LText('Aucune activité enregistrée pour le moment.'),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      final when = data['createdAt'];
                      final date = when is Timestamp ? when.toDate() : null;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.78),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: Colors.white.withOpacity(.9)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: ProspectoColors.green.withOpacity(.14),
                              foregroundColor: ProspectoColors.green,
                              child: Icon(_iconFor(data['action']?.toString())),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LText(
                                    (data['message'] ?? 'Action effectuée').toString(),
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  LText(
                                    '${data['actorEmail'] ?? 'Membre'}${date == null ? '' : ' • ${_format(date)}'}',
                                    style: const TextStyle(
                                      color: ProspectoColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  IconData _iconFor(String? action) {
    switch (action) {
      case 'prospect_created':
        return Icons.person_add_alt_1_rounded;
      case 'prospect_updated':
        return Icons.edit_rounded;
      case 'prospect_deleted':
        return Icons.delete_outline_rounded;
      case 'prospect_replanned':
        return Icons.event_repeat_rounded;
      case 'prospect_reported':
        return Icons.assessment_rounded;
      case 'member_joined':
        return Icons.group_add_rounded;
      case 'member_removed':
      case 'member_left':
      case 'member_account_deleted':
        return Icons.person_remove_rounded;
      case 'role_changed':
        return Icons.admin_panel_settings_rounded;
      case 'invite_created':
        return Icons.mark_email_unread_rounded;
      case 'invite_revoked':
        return Icons.mark_email_read_rounded;
      case 'organization_updated':
        return Icons.apartment_rounded;
      case 'ownership_transferred':
        return Icons.workspace_premium_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  String _format(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} à ${two(local.hour)}:${two(local.minute)}';
  }
}
