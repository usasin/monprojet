// lib/pages/map_page.dart
// UI 2026 — Glassmorphism, fond auroré animé, style aligné select_prospects_page

import 'dart:ui' as ui;

import 'package:auto_size_text/auto_size_text.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/localized_text.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/prospect.dart';
import '../providers/theme_provider.dart';
import '../services/access_control.dart';
import '../services/firestore_service.dart';
import '../widgets/brand_background.dart';

import '../theme/prospecto_colors.dart';

// ════════════════════════════════════════════════════════════════
//  Palette 2026
// ════════════════════════════════════════════════════════════════
class _P {
  static const indigo = ProspectoColors.blue;
  static const violet = ProspectoColors.green;
  static const sky = ProspectoColors.blueSoft;
  static const mint = ProspectoColors.green;
  static const coral = ProspectoColors.peach;
  static const amber = ProspectoColors.peachSoft;
  static const onLight = ProspectoColors.textPrimary;
  static const onLightSub = ProspectoColors.textSecondary;
  static const onDark = Color(0xFFF0F2FF);
  static const onDarkSub = Color(0xFF9099C4);

  static LinearGradient get primary => const LinearGradient(
        colors: [indigo, violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
  static LinearGradient get aurora => const LinearGradient(
        colors: [
          ProspectoColors.backgroundTop,
          ProspectoColors.blueMist,
          ProspectoColors.peachMist,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

// ════════════════════════════════════════════════════════════════
//  Page
// ════════════════════════════════════════════════════════════════
class MapPage extends StatefulWidget {
  static const routeName = '/map';
  const MapPage({Key? key, this.initialDate}) : super(key: key);
  final DateTime? initialDate;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with SingleTickerProviderStateMixin {
  DateTime _date = DateTime.now();
  bool _loading = false;
  List<Prospect> _route = [];

  late final AnimationController _listAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ok = await AccessControl.requireLogin(
        context,
        reason: "Pour afficher l'itinéraire, connecte-toi.",
      );
      if (!ok && mounted) {
        Navigator.of(context).maybePop();
        return;
      }
      await _loadRoute();
    });
  }

  @override
  void dispose() {
    _listAnim.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _loading = true;
    });
    try {
      final ids = await FirestoreService().loadPlan(_date);
      if (ids.isEmpty) {
        if (!mounted) return;
        setState(() {
          _route = [];
        });
        return;
      }
      final fetched = await FirestoreService().fetchProspectsByIds(ids);
      final byId = {for (final p in fetched) p.id: p};
      final ordered = <Prospect>[
        for (final id in ids)
          if (byId[id] != null) byId[id]!,
      ];
      if (!mounted) return;
      setState(() => _route = ordered);
      _listAnim.forward(from: 0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() => _date = d);
    await _loadRoute();
  }

  Uri? _buildGMapsUri(List<Prospect> list) {
    if (list.isEmpty) return null;
    final coords = list.take(24).map((p) => '${p.lat},${p.lng}').toList();
    final destination = coords.last;
    final waypoints = coords.length <= 2
        ? ''
        : coords.sublist(0, coords.length - 1).join('|');
    return Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$destination'
      '${waypoints.isNotEmpty ? '&waypoints=$waypoints' : ''}'
      '&travelmode=driving',
    );
  }

  Future<void> _openInMaps() async {
    final uri = _buildGMapsUri(_route);
    if (uri == null) {
      _toast('Aucun point dans la tournée.');
      return;
    }
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareRoute() async {
    final uri = _buildGMapsUri(_route);
    if (uri == null) return;
    await Share.share(
      'Itinéraire du ${DateFormat.yMd().format(_date)}\n${uri.toString()}',
      subject: 'Itinéraire Prospecto',
    );
  }

  Future<void> _openSingle(Prospect p) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${p.lat},${p.lng}&travelmode=driving',
    );
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _call(Prospect p) async {
    final phone = (p.phone ?? '').trim();
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: LText(msg),
        backgroundColor: _P.mint,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentTheme;
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final maxW =
        size.width >= 1024 ? 900.0 : (size.shortestSide >= 600 ? 720.0 : 560.0);

    return Theme(
      data: theme,
      child: BrandBackground(
        gradientColors: _P.aurora.colors,
        blurSigma: 14,
        animate: !_loading,
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
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Date picker
                          _GlassCard(
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  step: 1,
                                  icon: Icons.calendar_today_rounded,
                                  title: 'Date de la tournée',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _pickDate,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _P.indigo.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: _P.indigo.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_month_rounded,
                                          color: _P.indigo,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: AutoSizeText(
                                            DateFormat.yMMMMEEEEd(
                                              context.locale.languageCode,
                                            ).format(_date),
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isDark
                                                  ? _P.onDark
                                                  : _P.onLight,
                                            ),
                                            maxLines: 1,
                                            minFontSize: 12,
                                          ),
                                        ),
                                        Icon(
                                          Icons.edit_calendar_rounded,
                                          color: _P.indigo.withOpacity(0.6),
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          // ── Stats tournée
                          if (!_loading && _route.isNotEmpty)
                            _TourStatsCard(route: _route, isDark: isDark),

                          const SizedBox(height: 10),

                          // ── Liste
                          _GlassCard(
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  step: 2,
                                  icon: Icons.route_rounded,
                                  title:
                                      'Itinéraire (${_route.length} arrêt${_route.length > 1 ? 's' : ''})',
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                if (_loading)
                                  _LoadingRow()
                                else if (_route.isEmpty)
                                  _EmptyRoute(isDark: isDark)
                                else
                                  Column(
                                    children: List.generate(_route.length, (i) {
                                      final p = _route[i];
                                      return _RouteItem(
                                        prospect: p,
                                        index: i,
                                        total: _route.length,
                                        isDark: isDark,
                                        onNavigate: () => _openSingle(p),
                                        onCall:
                                            (p.phone ?? '').trim().isNotEmpty
                                                ? () => _call(p)
                                                : null,
                                      );
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
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
          child: Container(
            color: Colors.white.withOpacity(isDark ? 0.05 : 0.28),
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: _P.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.map_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LText(
              'Itinéraire'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? _P.onDark : _P.onLight,
              ),
            ),
          ),
        ],
      ),
      centerTitle: false,
      actions: [
        if (_route.isNotEmpty)
          _AppBarAction(
            icon: Icons.share_rounded,
            tooltip: 'Partager'.tr(),
            onTap: _shareRoute,
          ),
        _AppBarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Rafraîchir'.tr(),
          onTap: _loadRoute,
        ),
        const SizedBox(width: 8),
      ],
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
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.25),
                  width: 0.8,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                // Compteur
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: _route.isNotEmpty ? _P.primary : null,
                    color:
                        _route.isEmpty ? Colors.white.withOpacity(0.25) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _route.isNotEmpty
                        ? [
                            BoxShadow(
                              color: _P.indigo.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.pin_drop_rounded,
                        size: 18,
                        color:
                            _route.isNotEmpty ? Colors.white : Colors.black38,
                      ),
                      const SizedBox(width: 6),
                      LText(
                        '${_route.length} arrêt${_route.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          color:
                              _route.isNotEmpty ? Colors.white : Colors.black38,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Bouton démarrer
                Expanded(
                  child: _GradientButton(
                    label: 'Démarrer GPS'.tr(),
                    icon: Icons.navigation_rounded,
                    onTap: _route.isEmpty ? null : _openInMaps,
                  ),
                ),
              ],
            ),
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
            color: isDark
                ? Colors.white.withOpacity(0.07)
                : Colors.white.withOpacity(0.62),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.13)
                  : Colors.white.withOpacity(0.75),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
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
  const _SectionHeader({
    required this.step,
    required this.icon,
    required this.title,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            gradient: _P.primary,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: _P.indigo.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: LText(
            '$step',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: _P.indigo),
        const SizedBox(width: 8),
        Expanded(
          child: LText(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: isDark ? _P.onDark : _P.onLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _TourStatsCard extends StatelessWidget {
  final List<Prospect> route;
  final bool isDark;
  const _TourStatsCard({required this.route, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _P.indigo.withOpacity(0.12),
                _P.violet.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.indigo.withOpacity(0.22)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                value: '${route.length}',
                label: 'Arrêts',
                icon: Icons.pin_drop_rounded,
                color: _P.indigo,
              ),
              _StatDivider(),
              _StatItem(
                value: route
                    .where((p) => (p.phone ?? '').isNotEmpty)
                    .length
                    .toString(),
                label: 'Téléphones',
                icon: Icons.call_rounded,
                color: _P.mint,
              ),
              _StatDivider(),
              _StatItem(
                value: route
                    .where((p) => (p.website ?? '').isNotEmpty)
                    .length
                    .toString(),
                label: 'Sites web',
                icon: Icons.public_rounded,
                color: _P.sky,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        LText(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: color,
          ),
        ),
        LText(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _P.onLightSub,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 40, color: Colors.white.withOpacity(0.3));
}

class _RouteItem extends StatelessWidget {
  final Prospect prospect;
  final int index, total;
  final bool isDark;
  final VoidCallback onNavigate;
  final VoidCallback? onCall;
  const _RouteItem({
    required this.prospect,
    required this.index,
    required this.total,
    required this.isDark,
    required this.onNavigate,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Numéro + line
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: _P.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: _P.indigo.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: LText(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _P.indigo.withOpacity(0.3),
                      _P.indigo.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        // Contenu
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        prospect.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? _P.onDark : _P.onLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      LText(
                        prospect.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? _P.onDarkSub : _P.onLightSub,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (prospect.category.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _MiniChip(label: prospect.category, color: _P.indigo),
                      ],
                    ],
                  ),
                ),
                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconAction(
                      icon: Icons.navigation_rounded,
                      color: _P.indigo,
                      onTap: onNavigate,
                    ),
                    if (onCall != null) ...[
                      const SizedBox(width: 6),
                      _IconAction(
                        icon: Icons.call_rounded,
                        color: _P.mint,
                        onTap: onCall!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: LText(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptyRoute extends StatelessWidget {
  final bool isDark;
  const _EmptyRoute({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_P.sky.withOpacity(0.2), _P.violet.withOpacity(0.15)],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.map_outlined,
              size: 32,
              color: _P.indigo.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 14),
          LText(
            'Aucune tournée enregistrée',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? _P.onDarkSub : _P.onLightSub,
            ),
          ),
          const SizedBox(height: 4),
          LText(
            'Va dans "Planifier" puis enregistre ta tournée.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: (isDark ? _P.onDarkSub : _P.onLightSub).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
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
            gradient: enabled
                ? _P.primary
                : const LinearGradient(
                    colors: [Color(0xFF9099C4), Color(0xFF9099C4)],
                  ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: _P.indigo.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              LText(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onTap);
  }
}
