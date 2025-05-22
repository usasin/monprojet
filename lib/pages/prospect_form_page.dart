import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';

class ProspectFormPage extends StatefulWidget {
  static const routeName = '/prospect_new';
  const ProspectFormPage({Key? key}) : super(key: key);

  @override
  State<ProspectFormPage> createState() => _ProspectFormPageState();
}

class _ProspectFormPageState extends State<ProspectFormPage> {
  final _formKey = GlobalKey<FormState>();

  String  _name = '', _street = '', _zip = '', _city = '';
  double  _lat = 0.0, _lng = 0.0;
  String? _category;

  final _categories = ['boulangerie', 'pharmacie', 'restaurant', 'autre'];

  /* ───────────────────────── BUILD ───────────────────────── */
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs    = theme.colorScheme;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          title: Text('Nouveau prospect'.tr()),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                /* ----- Nom ----- */
                TextFormField(
                  decoration: InputDecoration(labelText: 'Nom'.tr()),
                  validator : (v) =>
                  v == null || v.trim().isEmpty ? 'Requis'.tr() : null,
                  onSaved: (v) => _name = v!.trim(),
                ),
                const SizedBox(height: 16),

                /* ----- Adresse ----- */
                TextFormField(
                  decoration: InputDecoration(labelText: 'Adresse'.tr()),
                  onSaved    : (v) => _street = v!.trim(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: 'Code postal'.tr()),
                        onSaved    : (v) => _zip = v!.trim(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        decoration: InputDecoration(labelText: 'Ville'.tr()),
                        onSaved    : (v) => _city = v!.trim(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                /* ----- Catégorie ----- */
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Catégorie'.tr()),
                  value     : _category,
                  items     : _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged : (v) => setState(() => _category = v),
                  validator : (v) => v == null ? 'Sélectionnez une catégorie'.tr() : null,
                ),
                const SizedBox(height: 32),

                /* ----- Bouton Ajouter ----- */
                FilledButton.icon(
                  icon : const Icon(Icons.check),
                  label: Text('Ajouter cet établissement'.tr()),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ───────────────────────── SUBMIT ───────────────────────── */
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final userId = FirebaseAuth.instance.currentUser!.uid;

    /* Données à sauvegarder */
    final prospectData = {
      'name'    : _name,
      'address' : '$_street, $_zip $_city',
      'lat'     : _lat,   // pourra être mis à jour plus tard
      'lng'     : _lng,
      'category': _category!,
    };

    /* Enregistrement Firestore + récupération ID */
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('prospects')
        .add(prospectData);

    /* Création objet Prospect pour renvoi */
    final newProspect = Prospect(
      id      : docRef.id,
      name    : _name,
      address : '$_street, $_zip $_city',
      lat     : _lat,
      lng     : _lng,
      category: _category!,
    );

    if (mounted) Navigator.pop(context, newProspect);
  }
}
