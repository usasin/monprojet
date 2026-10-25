// Configuration globale de recherche, geree uniquement par le developpeur.
// Les utilisateurs lisent les options; la modification passe par une
// Cloud Function qui verifie le claim Firebase prospectoDeveloper.
import 'package:cloud_functions/cloud_functions.dart';

import '../config.dart';

class ProspectSearchConfig {
  const ProspectSearchConfig({
    this.overpassEnabled = true,
    this.registryEnabled = true,
    this.expandedRestaurants = true,
  });

  final bool overpassEnabled;
  final bool registryEnabled;
  final bool expandedRestaurants;

  ProspectSearchConfig copyWith({
    bool? overpassEnabled,
    bool? registryEnabled,
    bool? expandedRestaurants,
  }) {
    return ProspectSearchConfig(
      overpassEnabled: overpassEnabled ?? this.overpassEnabled,
      registryEnabled: registryEnabled ?? this.registryEnabled,
      expandedRestaurants: expandedRestaurants ?? this.expandedRestaurants,
    );
  }

  factory ProspectSearchConfig.fromMap(Map<String, dynamic> data) {
    return ProspectSearchConfig(
      overpassEnabled: data['overpassEnabled'] is bool
          ? data['overpassEnabled'] as bool
          : true,
      registryEnabled: data['registryEnabled'] is bool
          ? data['registryEnabled'] as bool
          : true,
      expandedRestaurants: data['expandedRestaurants'] is bool
          ? data['expandedRestaurants'] as bool
          : true,
    );
  }

  Map<String, bool> toMap() => {
        'overpassEnabled': overpassEnabled,
        'registryEnabled': registryEnabled,
        'expandedRestaurants': expandedRestaurants,
      };
}

class ProspectSearchConfigService {
  ProspectSearchConfigService._();

  static final ProspectSearchConfigService instance =
      ProspectSearchConfigService._();

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  ProspectSearchConfig? _last;
  DateTime? _lastAt;
  Future<ProspectSearchConfig>? _inFlight;
  static const Duration _ttl = Duration(minutes: 5);

  Future<ProspectSearchConfig> load({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _last != null &&
        _lastAt != null &&
        DateTime.now().difference(_lastAt!) < _ttl) {
      return _last!;
    }
    if (_inFlight != null) return _inFlight!;

    final pending = _fetch();
    _inFlight = pending;
    try {
      return await pending;
    } finally {
      if (identical(_inFlight, pending)) _inFlight = null;
    }
  }

  Future<ProspectSearchConfig> _fetch() async {
    try {
      final response = await _functions
          .httpsCallable('getProspectSearchConfig')
          .call({'appId': kAppId})
          .timeout(const Duration(seconds: 5));
      final config = ProspectSearchConfig.fromMap(
        Map<String, dynamic>.from(response.data as Map),
      );
      _last = config;
      _lastAt = DateTime.now();
      return config;
    } catch (_) {
      // Ne jamais bloquer la prospection si le service de configuration
      // est indisponible ou si le client est temporairement hors ligne.
      return _last ?? const ProspectSearchConfig();
    }
  }

  Future<void> save(ProspectSearchConfig config) async {
    await _functions
        .httpsCallable('setProspectSearchConfig')
        .call({'appId': kAppId, ...config.toMap()})
        .timeout(const Duration(seconds: 12));
    _last = config;
    _lastAt = DateTime.now();
  }
}
