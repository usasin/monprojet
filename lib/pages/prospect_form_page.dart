// lib/pages/prospect_form_page.dart
// UI 2026 — Glassmorphism, fond auroré animé, style aligné select_prospects_page

import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/prospect.dart';
import '../services/firestore_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/brand_background.dart';

import '../theme/prospecto_colors.dart';
// ════════════════════════════════════════════════════════════════
//  Palette 2026
// ════════════════════════════════════════════════════════════════
class _P {
  static const indigo     = ProspectoColors.blue;
  static const violet     = ProspectoColors.green;
  static const sky        = ProspectoColors.blueSoft;
  static const mint       = ProspectoColors.green;
  static const coral      = ProspectoColors.peach;
  static const amber      = ProspectoColors.peachSoft;
  static const onLight    = ProspectoColors.textPrimary;
  static const onLightSub = ProspectoColors.textSecondary;
  static const onDark     = Color(0xFFF0F2FF);
  static const onDarkSub  = Color(0xFF9099C4);

  static LinearGradient get primary => const LinearGradient(
    colors: [indigo, violet], begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static LinearGradient get aurora => const LinearGradient(
    colors: [ProspectoColors.backgroundTop, ProspectoColors.blueMist, ProspectoColors.peachMist],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
}

// ════════════════════════════════════════════════════════════════
//  Page
// ════════════════════════════════════════════════════════════════
class ProspectFormPage extends StatefulWidget {
  static const routeName = '/prospect_new';
  const ProspectFormPage({Key? key}) : super(key: key);

  @override
  State<ProspectFormPage> createState() => _ProspectFormPageState();
}

class _ProspectFormPageState extends State<ProspectFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl    = TextEditingController();
  final _streetCtrl  = TextEditingController();
  final _zipCtrl     = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _openingHoursCtrl = TextEditingController();

  double   _lat = 0.0, _lng = 0.0;
  String?  _category;
  int      _priority = 3;
  int      _visitDurationMinutes = 30;
  DateTime? _appointmentAt;
  bool     _saving = false;
  String?  _error;

  static const _categories = [
    'Boulangerie', 'Pharmacie', 'Restaurant', 'Coiffeur',
    'Garage', 'Bureau', 'Commerce', 'Artisan', 'Autre',
  ];

  @override
  void dispose() {
    for (final c in [_nameCtrl, _streetCtrl, _zipCtrl, _cityCtrl,
      _phoneCtrl, _emailCtrl, _websiteCtrl, _openingHoursCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      final prospect = Prospect(
        id: '',
        name: _nameCtrl.text.trim(),
        address: '${_streetCtrl.text.trim()}, ${_zipCtrl.text.trim()} ${_cityCtrl.text.trim()}',
        lat: _lat,
        lng: _lng,
        category: _category ?? 'Autre',
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        website: _websiteCtrl.text.trim(),
        openingHours: _openingHoursCtrl.text.trim(),
        priority: _priority,
        visitDurationMinutes: _visitDurationMinutes,
        appointmentAt: _appointmentAt,
      );
      await FirestoreService().addProspect(prospect);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: LText(msg),
      backgroundColor: isError ? _P.coral : _P.mint,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme  = context.watch<ThemeProvider>().currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final size   = MediaQuery.of(context).size;
    final maxW   = size.width >= 1024 ? 900.0 : (size.shortestSide >= 600 ? 600.0 : 520.0);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _P.aurora.colors,
        blurSigma: 14,
        animate: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(isDark),
          bottomNavigationBar: _buildBottomBar(isDark),
          body: SafeArea(
            top: true,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),

                        // ── Infos principales
                        _GlassCard(isDark: isDark, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(step: 1, icon: Icons.business_rounded, title: 'Informations principales', isDark: isDark),
                            const SizedBox(height: 14),
                            _Field(label: 'Nom de l\'établissement *', icon: Icons.storefront_rounded,
                                controller: _nameCtrl, required: true),
                            const SizedBox(height: 10),
                            // Catégorie
                            _CategorySelector(
                              value: _category,
                              categories: _categories,
                              onChanged: (v) => setState(() => _category = v),
                            ),
                          ],
                        )),
                        const SizedBox(height: 10),

                        // ── Adresse
                        _GlassCard(isDark: isDark, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(step: 2, icon: Icons.location_on_rounded, title: 'Adresse', isDark: isDark),
                            const SizedBox(height: 14),
                            _Field(label: 'Rue & numéro *', icon: Icons.signpost_rounded,
                                controller: _streetCtrl, required: true),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(child: _Field(label: 'Code postal', icon: Icons.local_post_office_rounded,
                                  controller: _zipCtrl, keyboardType: TextInputType.number)),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: _Field(label: 'Ville *', icon: Icons.location_city_rounded,
                                  controller: _cityCtrl, required: true)),
                            ]),
                            const SizedBox(height: 10),
                            // Coords optionnelles
                            Row(children: [
                              Expanded(child: _CoordField(label: 'Latitude', value: _lat,
                                  onChanged: (v) => setState(() => _lat = v))),
                              const SizedBox(width: 10),
                              Expanded(child: _CoordField(label: 'Longitude', value: _lng,
                                  onChanged: (v) => setState(() => _lng = v))),
                            ]),
                          ],
                        )),
                        const SizedBox(height: 10),

                        // ── Contact
                        _GlassCard(isDark: isDark, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(step: 3, icon: Icons.contact_phone_rounded, title: 'Contact (optionnel)', isDark: isDark),
                            const SizedBox(height: 14),
                            _Field(label: 'Téléphone', icon: Icons.call_rounded,
                                controller: _phoneCtrl, keyboardType: TextInputType.phone),
                            const SizedBox(height: 10),
                            _Field(label: 'Email', icon: Icons.email_rounded,
                                controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 10),
                            _Field(label: 'Site web', icon: Icons.public_rounded,
                                controller: _websiteCtrl, keyboardType: TextInputType.url),
                          ],
                        )),
                        const SizedBox(height: 10),

                        // ── Contraintes de tournée
                        _GlassCard(isDark: isDark, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(step: 4, icon: Icons.auto_awesome_rounded,
                                title: 'Planification intelligente', isDark: isDark),
                            const SizedBox(height: 14),
                            _Field(
                              label: 'Horaires d’ouverture (ex. Mo-Fr 09:00-18:00)',
                              icon: Icons.schedule_rounded,
                              controller: _openingHoursCtrl,
                            ),
                            const SizedBox(height: 14),
                            LText('Priorité : $_priority / 5',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Slider(
                              value: _priority.toDouble(), min: 1, max: 5, divisions: 4,
                              label: 'Priorité $_priority',
                              onChanged: (v) => setState(() => _priority = v.round()),
                            ),
                            LText('Durée de visite : $_visitDurationMinutes min',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Slider(
                              value: _visitDurationMinutes.toDouble(), min: 15, max: 90, divisions: 5,
                              label: '$_visitDurationMinutes min',
                              onChanged: (v) => setState(() => _visitDurationMinutes = v.round()),
                            ),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _appointmentAt ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 730)),
                                );
                                if (date == null || !mounted) return;
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                    _appointmentAt ?? DateTime(date.year, date.month, date.day, 9),
                                  ),
                                );
                                if (time == null) return;
                                setState(() => _appointmentAt = DateTime(
                                  date.year, date.month, date.day, time.hour, time.minute,
                                ));
                              },
                              icon: const Icon(Icons.event_available_rounded),
                              label: LText(_appointmentAt == null
                                  ? 'Ajouter un rendez-vous fixe'
                                  : 'Rendez-vous : ${_appointmentAt!.day.toString().padLeft(2, '0')}/'
                                    '${_appointmentAt!.month.toString().padLeft(2, '0')} '
                                    '${_appointmentAt!.hour.toString().padLeft(2, '0')}:'
                                    '${_appointmentAt!.minute.toString().padLeft(2, '0')}'),
                            ),
                            if (_appointmentAt != null)
                              TextButton.icon(
                                onPressed: () => setState(() => _appointmentAt = null),
                                icon: const Icon(Icons.close_rounded),
                                label: const LText('Retirer le rendez-vous'),
                              ),
                          ],
                        )),

                        // ── Erreur
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _P.coral.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _P.coral.withOpacity(0.3)),
                            ),
                            child: Row(children: [
                              Icon(Icons.error_outline_rounded, color: _P.coral, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: LText(_error!, style: const TextStyle(color: _P.coral, fontWeight: FontWeight.w600))),
                            ]),
                          ),
                        ],
                      ],
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

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 8,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.white.withOpacity(isDark ? 0.05 : 0.28)),
        ),
      ),
      title: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LText(
            'Nouveau prospect'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? _P.onDark : _P.onLight,
            ),
          ),
        ),
      ]),
      centerTitle: false,
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.25), width: 0.8)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              _GlassIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Annuler'.tr(),
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 12),
              Expanded(child: _GradientButton(
                label: _saving ? 'Enregistrement…' : 'Ajouter le prospect'.tr(),
                icon: Icons.add_rounded,
                onTap: _saving ? null : _save,
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Widgets
// ════════════════════════════════════════════════════════════════

class _GlassCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _GlassCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white.withOpacity(0.13) : Colors.white.withOpacity(0.75)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 6))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final bool isDark;
  const _SectionHeader({required this.step, required this.icon, required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(gradient: _P.primary, borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: _P.indigo.withOpacity(0.35), blurRadius: 8, offset: const Offset(0, 4))]),
        alignment: Alignment.center,
        child: LText('$step', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
      ),
      const SizedBox(width: 10),
      Icon(icon, size: 18, color: _P.indigo),
      const SizedBox(width: 8),
      Expanded(child: LText(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15,
          color: isDark ? _P.onDark : _P.onLight))),
    ]);
  }
}

class _Field extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool required;
  final TextInputType? keyboardType;
  const _Field({required this.label, required this.icon, required this.controller,
      this.required = false, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Champ requis' : null : null,
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.70),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: _P.onLightSub),
        prefixIcon: Icon(icon, color: _P.indigo, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _P.indigo.withOpacity(0.18))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.35))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.indigo, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.coral)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _CoordField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _CoordField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      initialValue: value == 0.0 ? '' : value.toString(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.70),
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: _P.onLightSub),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _P.indigo.withOpacity(0.18))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.35))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _P.indigo, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (v) { final d = double.tryParse(v); if (d != null) onChanged(d); },
    );
  }
}

class _CategorySelector extends StatelessWidget {
  final String? value;
  final List<String> categories;
  final ValueChanged<String?> onChanged;
  const _CategorySelector({this.value, required this.categories, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: categories.map((cat) {
      final selected = value == cat;
      return GestureDetector(
        onTap: () => onChanged(selected ? null : cat),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: selected ? _P.primary : null,
            color: selected ? null : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? Colors.transparent : Colors.white.withOpacity(0.6)),
            boxShadow: selected ? [BoxShadow(color: _P.indigo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
          ),
          child: LText(cat, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _P.onLightSub,
          )),
        ),
      );
    }).toList());
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            gradient: enabled ? _P.primary : const LinearGradient(colors: [Color(0xFF9099C4), Color(0xFF9099C4)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled ? [BoxShadow(color: _P.indigo.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))] : [],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            LText(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Icon(icon, color: Colors.black54, size: 22),
        ),
      ),
    );
  }
}
