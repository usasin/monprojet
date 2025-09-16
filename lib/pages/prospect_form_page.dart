import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_background.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final cs    = theme.colorScheme;

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: const [Color(0xFFDEEFFF), Color(0xFFB3C7FF), Color(0xFFDCC8FF)],
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Nouveau prospect'.tr(), style: const TextStyle(fontWeight: FontWeight.w800)),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Card(
                  color: cs.surfaceContainerHighest.withOpacity(.95),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        children: [
                          /* ----- Nom ----- */
                          TextFormField(
                            decoration: InputDecoration(labelText: 'Nom'.tr()),
                            validator : (v) => v == null || v.trim().isEmpty ? 'Requis'.tr() : null,
                            onSaved   : (v) => _name = v!.trim(),
                          ),
                          const SizedBox(height: 16),

                          /* ----- Adresse ----- */
                          TextFormField(
                            decoration: InputDecoration(labelText: 'Adresse'.tr()),
                            onSaved   : (v) => _street = v!.trim(),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(labelText: 'Code postal'.tr()),
                                  onSaved   : (v) => _zip = v!.trim(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  decoration: InputDecoration(labelText: 'Ville'.tr()),
                                  onSaved   : (v) => _city = v!.trim(),
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
                                .map((c) => DropdownMenuItem(value: c, child: Text(c.tr())))
                                .toList(),
                            onChanged : (v) => setState(() => _category = v),
                            validator : (v) => v == null ? 'Sélectionnez une catégorie'.tr() : null,
                          ),

                          const SizedBox(height: 12),
                          // lat/lng (optionnel, pour édition rapide)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: const InputDecoration(labelText: 'Lat (optionnel)'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                                  onSaved: (v) => _lat = double.tryParse(v ?? '') ?? 0.0,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  decoration: const InputDecoration(labelText: 'Lng (optionnel)'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                                  onSaved: (v) => _lng = double.tryParse(v ?? '') ?? 0.0,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          /* ----- Bouton Ajouter ----- */
                          FilledButton.icon(
                            icon : const Icon(Icons.check_rounded),
                            label: Text('Ajouter cet établissement'.tr()),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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

    final addr = [
      if (_street.trim().isNotEmpty) _street.trim(),
      [if (_zip.trim().isNotEmpty) _zip.trim(), if (_city.trim().isNotEmpty) _city.trim()].where((e) => e.isNotEmpty).join(' ')
    ].where((e) => e.isNotEmpty).join(', ');

    final prospectData = {
      'name'    : _name,
      'address' : addr,
      'lat'     : _lat,   // pourra être enrichi plus tard
      'lng'     : _lng,
      'category': _category!,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('prospects')
        .add(prospectData);

    final newProspect = Prospect(
      id      : docRef.id,
      name    : _name,
      address : addr,
      lat     : _lat,
      lng     : _lng,
      category: _category!,
    );

    if (mounted) Navigator.pop(context, newProspect);
  }
}
