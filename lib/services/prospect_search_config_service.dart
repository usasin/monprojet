import 'package:cloud_functions/cloud_functions.dart';
import '../config.dart';

class ProspectSearchConfig {
  const ProspectSearchConfig({this.overpassEnabled=true,
    this.registryEnabled=true, this.expandedRestaurants=true});
  final bool overpassEnabled;
  final bool registryEnabled;
  final bool expandedRestaurants;

  ProspectSearchConfig copyWith({bool? overpassEnabled,bool? registryEnabled,
      bool? expandedRestaurants}) => ProspectSearchConfig(
    overpassEnabled:overpassEnabled??this.overpassEnabled,
    registryEnabled:registryEnabled??this.registryEnabled,
    expandedRestaurants:expandedRestaurants??this.expandedRestaurants,
  );
  factory ProspectSearchConfig.fromMap(Map<String,dynamic> data) => ProspectSearchConfig(
    overpassEnabled:data['overpassEnabled'] is bool ? data['overpassEnabled'] as bool : true,
    registryEnabled:data['registryEnabled'] is bool ? data['registryEnabled'] as bool : true,
    expandedRestaurants:data['expandedRestaurants'] is bool ? data['expandedRestaurants'] as bool : true,
  );
  Map<String,bool> toMap() => {
    'overpassEnabled':overpassEnabled,
    'registryEnabled':registryEnabled,
    'expandedRestaurants':expandedRestaurants,
  };
}

class ProspectSearchConfigService {
  ProspectSearchConfigService._();
  static final instance = ProspectSearchConfigService._();
  final _fn = FirebaseFunctions.instanceFor(region:'europe-west1');
  ProspectSearchConfig? _cache;
  DateTime? _cachedAt;
  Future<ProspectSearchConfig>? _pending;

  Future<ProspectSearchConfig> load({bool forceRefresh=false}) async {
    if (!forceRefresh && _cache!=null && _cachedAt!=null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes:5)) return _cache!;
    if (_pending!=null) return _pending!;
    final future = _fetch();_pending=future;
    try {return await future;} finally {
      if (identical(_pending,future)) _pending=null;
    }
  }

  Future<ProspectSearchConfig> _fetch() async {
    try {
      final response = await _fn.httpsCallable('getProspectSearchConfig')
          .call({'appId':kAppId}).timeout(const Duration(seconds:2));
      final config=ProspectSearchConfig.fromMap(Map<String,dynamic>.from(response.data as Map));
      _cache=config;_cachedAt=DateTime.now();return config;
    } catch (_) {
      return _cache ?? const ProspectSearchConfig();
    }
  }

  Future<void> save(ProspectSearchConfig config) async {
    await _fn.httpsCallable('setProspectSearchConfig')
        .call({'appId':kAppId,...config.toMap()})
        .timeout(const Duration(seconds:12));
    _cache=config;_cachedAt=DateTime.now();
  }
}
