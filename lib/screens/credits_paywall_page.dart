import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/access_control.dart';

import '../services/ad_service.dart';
import '../services/in_app_purchase_service.dart';
import '../services/purchase_delivery.dart';
import '../services/usage_meter.dart';
import '../theme/prospecto_colors.dart';

/// Paywall abonnement (sans crédits / sans packs).
///
/// Gratuit:
/// - 1 tournée enregistrée
/// - jusqu'à 3 clients par tournée
///
/// Premium:
/// - tournées & clients illimités
/// - optimisation offline
/// - sans pub
class CreditsPaywallPage extends StatefulWidget {
  const CreditsPaywallPage({super.key, this.usageMeter});

  final UsageMeter? usageMeter;

  @override
  State<CreditsPaywallPage> createState() => _CreditsPaywallPageState();
}

class _CreditsPaywallPageState extends State<CreditsPaywallPage> {
  bool get _apple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  late final _meter = widget.usageMeter ?? UsageMeter();
  late final InAppPurchaseService _iap;

  bool _loading = true;
  bool _loadingProducts = true;
  bool _isPurchasing = false;
  String? _productsError;

  bool _isPremium = false;
  bool _restoreRequestedByUser = false;

  @override
  void initState() {
    super.initState();

    _iap = InAppPurchaseService(
      onDeliverPurchase: (PurchaseDetails p) async => _deliver(p),
    );

    _boot();
  }

  @override
  void dispose() {
    _iap.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (_apple) {
      // StoreKit prices and subscription information must remain visible even
      // when Firestore is slow. Restoration is only requested by the user.
      setState(() => _loading = false);
      unawaited(_refreshAppleEntitlements());
      await _loadProductsWithRetry();
      return;
    }
    try {
      await _meter.initIfNeeded();
      await _meter.syncFromCloud();
      await _iap.init();
      // Restore silencieux pour resync premium à l'ouverture.
      try {
        await _iap.restore();
      } catch (_) {}
      await _refresh();
      if (mounted) await _loadProductsWithRetry();
    } catch (_) {
      _productsError =
          'Les abonnements sont temporairement indisponibles. Réessayez plus tard.';
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _loadingProducts = false;
        });
    }
  }

  Future<void> _refreshAppleEntitlements() async {
    try {
      await _refresh().timeout(const Duration(seconds: 10));
    } catch (_) {
      // A cloud outage must not hide the StoreKit catalogue.
    }
  }

  Future<void> _refresh() async {
    await _meter.syncFromCloud();
    final premium = await _meter.isPremium();
    AdService.instance.setPremiumStatus(premium);
    if (!mounted) return;
    setState(() => _isPremium = premium);
  }

  Future<void> _loadProductsWithRetry() async {
    if (!mounted) return;
    setState(() {
      _loadingProducts = true;
      _productsError = null;
    });

    try {
      final ok = await _iap.loadProducts();
      if (!mounted) return;
      if (!ok ||
          _iap.getProduct(InAppPurchaseService.premiumMonthly) == null ||
          _iap.getProduct(InAppPurchaseService.premiumYearly) == null) {
        _productsError =
            "Les abonnements sont temporairement indisponibles. Réessayez plus tard.";
      }
    } catch (_) {
      if (!mounted) return;
      _productsError =
          'Les abonnements sont temporairement indisponibles. Réessayez plus tard.';
    }

    if (!mounted) return;
    setState(() => _loadingProducts = false);
  }

  Future<bool> _deliver(PurchaseDetails p) async {
    final res = await PurchaseDelivery.deliver(p, meter: _meter);
    await _refresh();

    if (mounted &&
        res.message != null &&
        (_restoreRequestedByUser || p.status == PurchaseStatus.purchased)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LText(res.message!)));
    }
    return res.delivered || res.ignored;
  }

  Future<void> _buy(ProductDetails product) async {
    if (!await AccessControl.requireLogin(
      context,
      reason: 'Connectez-vous pour conserver votre abonnement.',
    ))
      return;
    if (!mounted) return;
    setState(() => _isPurchasing = true);
    try {
      await _iap.buy(product);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LText('L’achat n’a pas pu démarrer. Réessayez.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    if (!await AccessControl.requireLogin(
      context,
      reason: 'Connectez-vous pour restaurer votre abonnement.',
    ))
      return;
    if (!mounted) return;
    setState(() => _restoreRequestedByUser = true);
    try {
      await _iap.restore();
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LText('Restauration indisponible. Réessayez plus tard.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _restoreRequestedByUser = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final pMonthly = _iap.getProduct(InAppPurchaseService.premiumMonthly);
    final pYearly = _iap.getProduct(InAppPurchaseService.premiumYearly);

    return Scaffold(
      appBar: AppBar(
        title: const LText("Premium"),
        actions: [
          TextButton(
            onPressed: _restoreRequestedByUser ? null : _restore,
            child: const LText("Restaurer"),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        _isPremium
                            ? "Premium activé ✅"
                            : "Débloque toutes les fonctionnalités",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const LText(
                        "Gratuit : 1 tournée enregistrée • jusqu’à 3 clients",
                      ),
                      const SizedBox(height: 6),
                      const LText(
                        "Premium : illimité • optimisation • historique • sans pub",
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_loadingProducts)
                  const Center(child: CircularProgressIndicator()),
                if (_productsError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LText(
                          _productsError!,
                          style: TextStyle(color: cs.error),
                        ),
                        TextButton.icon(
                          onPressed: _loadingProducts
                              ? null
                              : _loadProductsWithRetry,
                          icon: const Icon(Icons.refresh),
                          label: const LText('Réessayer'),
                        ),
                      ],
                    ),
                  ),

                if (!_isPremium &&
                    !_loadingProducts &&
                    pMonthly == null &&
                    pYearly == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(
                          alpha: 0.35,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: LText(
                        'Les offres sont temporairement indisponibles. Réessayez dans quelques instants.',
                      ),
                    ),
                  ),

                _PlanTile(
                  title: "Mensuel",
                  subtitle:
                      pMonthly?.price ??
                      (_loadingProducts
                          ? 'Chargement du prix…'
                          : 'Offre indisponible'),
                  enabled: !_isPurchasing && !_isPremium && pMonthly != null,
                  onTap: pMonthly == null ? null : () => _buy(pMonthly),
                ),
                const SizedBox(height: 10),
                _PlanTile(
                  title: "Annuel",
                  subtitle:
                      pYearly?.price ??
                      (_loadingProducts
                          ? 'Chargement du prix…'
                          : 'Offre indisponible'),
                  enabled: !_isPurchasing && !_isPremium && pYearly != null,
                  onTap: pYearly == null ? null : () => _buy(pYearly),
                  highlight: true,
                ),

                const SizedBox(height: 16),
                LText(
                  _apple
                      ? 'Abonnement mensuel ou annuel avec renouvellement automatique. Le paiement est débité de votre compte Apple. Gérez ou annulez l’abonnement dans les réglages de votre compte Apple avant la fin de la période en cours.'
                      : 'Résiliable à tout moment depuis Google Play. L’abonnement se renouvelle automatiquement sauf annulation.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Wrap(
                  children: [
                    if (_apple)
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.parse(
                            'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: const LText('Conditions d’utilisation'),
                      ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/information'),
                      child: const LText('Confidentialité'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;
  final bool highlight;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            width: highlight ? 2 : 1,
            color: highlight ? ProspectoColors.green : cs.outline,
          ),
          color: highlight
              ? ProspectoColors.green.withValues(alpha: 0.08)
              : cs.surface,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LText(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  LText(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
