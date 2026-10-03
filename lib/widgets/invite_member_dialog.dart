import 'package:flutter/material.dart';

/// Controllers live as long as the dialog route, including its exit animation.
class InviteMemberDialog extends StatefulWidget {
  const InviteMemberDialog({super.key, required this.managers});
  final Map<String, String> managers;
  @override
  State<InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<InviteMemberDialog> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  String _role = 'REP';
  String _manager = '';

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    title: const Text('Inviter un membre'),
    content: SizedBox(
      width: 420,
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _first,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: _required,
            ),
            TextFormField(
              controller: _last,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: _required,
            ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                helperText: 'Le code sera réservé à cette adresse.',
                helperMaxLines: 3,
              ),
              validator: (v) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Adresse e-mail valide requise',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _role,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(
                  value: 'REP',
                  child: Text('Commercial', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'MANAGER',
                  child: Text(
                    'Responsable commercial',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
            if (_role == 'REP') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _manager,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Responsable commercial',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Suivi par l’administrateur',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...widget.managers.entries.map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _manager = v!),
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(context, {
            'firstName': _first.text.trim(),
            'lastName': _last.text.trim(),
            'email': _email.text.trim().toLowerCase(),
            'role': _role,
            'managerUid': _role == 'REP' ? _manager : '',
          });
        },
        child: const Text('Créer le code'),
      ),
    ],
  );
  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Champ obligatoire' : null;
}
