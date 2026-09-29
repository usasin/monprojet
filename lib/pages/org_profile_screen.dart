import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../providers/org_provider.dart';
import '../services/org_service.dart';
import '../theme/prospecto_colors.dart';
import '../widgets/brand_background.dart';
import '../widgets/company_avatar.dart';

class OrgProfileScreen extends StatefulWidget {
  static const routeName = '/org_profile';
  const OrgProfileScreen({super.key});

  @override
  State<OrgProfileScreen> createState() => _OrgProfileScreenState();
}

class _OrgProfileScreenState extends State<OrgProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _sloganCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  bool _initialized = false;
  bool _busy = false;
  String? _logoUrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final org = context.read<OrgProvider>();
    _nameCtrl.text = org.orgName ?? '';
    _sloganCtrl.text = org.slogan ?? '';
    _emailCtrl.text = org.companyEmail ?? '';
    _phoneCtrl.text = org.companyPhone ?? '';
    _websiteCtrl.text = org.website ?? '';
    _logoUrl = org.logoUrl;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _sloganCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _persistLogo(
    OrgProvider org,
    String orgId,
    String? logoUrl,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Vous devez être connecté.';
    await OrgService(kAppId).updateOrganizationProfile(
      orgId: orgId,
      name: org.orgName ?? 'Entreprise',
      slogan: org.slogan,
      logoUrl: logoUrl,
      companyEmail: org.companyEmail,
      companyPhone: org.companyPhone,
      website: org.website,
    );
    if (!mounted) return;
    await context.read<OrgProvider>().refresh(user.uid);
  }

  Future<void> _pickLogo() async {
    if (_busy) return;
    final org = context.read<OrgProvider>();
    final orgId = org.orgId;
    if (!org.isOwner || orgId == null) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw 'Le logo doit peser moins de 5 Mo.';
      }
      final ref = FirebaseStorage.instance.ref(
        'apps/$kAppId/orgs/$orgId/branding/logo.jpg',
      );
      final snapshot = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await snapshot.ref.getDownloadURL();
      await _persistLogo(org, orgId, url);
      if (mounted) {
        setState(() => _logoUrl = url);
        _snack('Logo de l’entreprise mis à jour.');
      }
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeLogo() async {
    if (_busy) return;
    final org = context.read<OrgProvider>();
    final orgId = org.orgId;
    if (!org.isOwner || orgId == null) return;
    setState(() => _busy = true);
    try {
      final ref = FirebaseStorage.instance.ref(
        'apps/$kAppId/orgs/$orgId/branding/logo.jpg',
      );
      try {
        await ref.delete();
      } on FirebaseException catch (error) {
        if (error.code != 'object-not-found') rethrow;
      }
      await _persistLogo(org, orgId, null);
      if (mounted) {
        setState(() => _logoUrl = null);
        _snack('Logo retiré. Les initiales sont maintenant affichées.');
      }
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    final org = context.read<OrgProvider>();
    final orgId = org.orgId;
    final user = FirebaseAuth.instance.currentUser;
    if (!org.isOwner || orgId == null || user == null) return;
    setState(() => _busy = true);
    try {
      await OrgService(kAppId).updateOrganizationProfile(
        orgId: orgId,
        name: _nameCtrl.text,
        slogan: _sloganCtrl.text,
        logoUrl: _logoUrl,
        companyEmail: _emailCtrl.text,
        companyPhone: _phoneCtrl.text,
        website: _websiteCtrl.text,
      );
      if (!mounted) return;
      await context.read<OrgProvider>().refresh(user.uid);
      if (!mounted) return;
      _snack('Identité de l’entreprise mise à jour.');
    } catch (error) {
      _snack(error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LText(message.replaceFirst('Bad state: ', '')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final org = context.watch<OrgProvider>();
    final editable = org.isOwner;
    return BrandBackground(
      animate: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const LText(
            'Identité de l’entreprise',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.78),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withOpacity(.9)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CompanyAvatar(
                                initials: org.initials,
                                logoUrl: _logoUrl,
                                size: 94,
                              ),
                              if (editable)
                                Positioned(
                                  right: -7,
                                  bottom: -7,
                                  child: IconButton.filled(
                                    onPressed: _busy ? null : _pickLogo,
                                    tooltip: 'Changer le logo'.tr(),
                                    icon: const Icon(Icons.photo_camera_rounded),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (editable && _logoUrl?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: _busy ? null : _removeLogo,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const LText('Retirer le logo'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        _field(
                          controller: _nameCtrl,
                          label: 'Nom de l’entreprise',
                          icon: Icons.apartment_rounded,
                          enabled: editable,
                          maxLength: 100,
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Le nom est requis.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _sloganCtrl,
                          label: 'Slogan (facultatif)',
                          icon: Icons.format_quote_rounded,
                          enabled: editable,
                          maxLength: 100,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _emailCtrl,
                          label: 'E-mail professionnel',
                          icon: Icons.alternate_email_rounded,
                          enabled: editable,
                          maxLength: 254,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _phoneCtrl,
                          label: 'Téléphone',
                          icon: Icons.phone_rounded,
                          enabled: editable,
                          maxLength: 40,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        _field(
                          controller: _websiteCtrl,
                          label: 'Site internet',
                          icon: Icons.language_rounded,
                          enabled: editable,
                          maxLength: 200,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 18),
                        if (editable)
                          FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: const LText('Enregistrer'),
                          )
                        else
                          const LText(
                            'Seul l’administrateur principal peut modifier ces informations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: ProspectoColors.textSecondary),
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
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool enabled,
    required int maxLength,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: ProspectoColors.green),
        filled: true,
        fillColor: Colors.white.withOpacity(.72),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
