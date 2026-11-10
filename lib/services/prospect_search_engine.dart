// Overpass mondial + Annuaire France en complement, avec attentes bornees.
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'french_registry_service.dart';
import 'osm_search_service.dart';
import 'prospect_search_config_service.dart';

class ProspectSearchEngine {
  final _osm=OSMSearchService();
  final _registry=FrenchRegistryService();
  static final Map<String,_Entry> _cache={};
  static final Map<String,Future<List<OSMPlace>>> _pending={};

  Future<List<OSMPlace>> searchNearby({required double lat,required double lng,
      required String query,required int radiusMeters,
      String languageCode='fr',String? countryCode}) async {
    // La Cloud Function d'administration n'est pas déployée : ne pas attendre
    // ni dépendre d'un appel Firebase pour chercher des prospects.
    const cfg=ProspectSearchConfig(
        overpassEnabled:true, registryEnabled:true,
        expandedRestaurants:false);
    final key='${lat.toStringAsFixed(5)}|${lng.toStringAsFixed(5)}|'
        '$radiusMeters|${query.toLowerCase()}|$languageCode|$countryCode|${cfg.toMap()}';
    final stale=_cache[key];
    if(stale!=null&&DateTime.now().difference(stale.date)<const Duration(minutes:10))return stale.places;
    if(_pending[key]!=null)return _pending[key]!;
    final request=_run(lat:lat,lng:lng,query:query,radiusMeters:radiusMeters,
        languageCode:languageCode,countryCode:countryCode,cfg:cfg,key:key,stale:stale);
    _pending[key]=request;
    try {
      final data=await request;
      if(data.isNotEmpty)_store(key,data);
      return data;
    } finally {
      if(identical(_pending[key],request))_pending.remove(key);
    }
  }

  Future<List<OSMPlace>> _run({required double lat,required double lng,
      required String query,required int radiusMeters,required String languageCode,
      required String? countryCode,required ProspectSearchConfig cfg,
      required String key,required _Entry? stale}) async {
    if(!cfg.overpassEnabled&&!cfg.registryEnabled)throw StateError('Aucune source active');
    var osm=<OSMPlace>[];var registry=<OSMPlace>[];
    var complete=0;var fails=0;
    final tasks=<Future<void>>[];final first=Completer<void>();
    if(cfg.overpassEnabled) {
      tasks.add(_osm.searchNearby(lat:lat,lng:lng,query:query,
          radiusMeters:radiusMeters,languageCode:languageCode,
          expandedRestaurants:cfg.expandedRestaurants).then((p){
        osm=p;complete++;
        debugPrint('PROSPECTO_SEARCH_OSM count=${p.length}');
        if(p.isNotEmpty&&!first.isCompleted)first.complete();
      }).catchError((Object error){
        fails++;complete++;
        debugPrint('PROSPECTO_SEARCH_OSM_ERROR: $error');
      }));
    }
    if(cfg.registryEnabled&&countryCode?.toLowerCase()=='fr'&&
        FrenchRegistryService.supportsLocation(lat,lng)&&
        FrenchRegistryService.nafCodesFor(query)!=null) {
      tasks.add(_registry.searchNearby(lat:lat,lng:lng,
          radiusMeters:radiusMeters,query:query).then((p){
        registry=p;complete++;
        debugPrint('PROSPECTO_SEARCH_ANNUAIRE count=${p.length}');
        if(p.isNotEmpty&&!first.isCompleted)first.complete();
      }).catchError((Object error){
        fails++;complete++;
        debugPrint('PROSPECTO_SEARCH_ANNUAIRE_ERROR: $error');
      }));
    }
    if(tasks.isEmpty)throw StateError('Aucune source disponible pour cette zone');
    final all=Future.wait<void>(tasks);
    all.then<void>((_){
      final enriched=_merge(lat,lng,osm,registry);
      if(enriched.isNotEmpty)_store(key,enriched);
    });
    await Future.any<void>([
      all.then<void>((_){}),
      first.future.then<void>((_)=>
          Future<void>.delayed(const Duration(milliseconds:1200))),
      Future<void>.delayed(const Duration(seconds:20)),
    ]);
    final results=_merge(lat,lng,osm,registry);
    if(results.isNotEmpty)return results;
    if(stale!=null&&DateTime.now().difference(stale.date)<const Duration(hours:1))return stale.places;
    if(complete<tasks.length)throw TimeoutException('Recherche : delai depasse (20s)');
    if(fails==tasks.length)throw StateError('Serveurs de recherche occupes');
    return const [];
  }

  static void _store(String key,List<OSMPlace> value){
    _cache.remove(key);_cache[key]=_Entry(value,DateTime.now());
    while(_cache.length>40)_cache.remove(_cache.keys.first);
  }

  static List<OSMPlace> _merge(double lat,double lng,
      List<OSMPlace> first,List<OSMPlace> second){
    final out=<OSMPlace>[...first];
    for(final p in second){
      final match=out.indexWhere((q){
        if(_distance(p.lat,p.lng,q.lat,q.lng)>35)return false;
        final a=_name(p.name),b=_name(q.name);
        return a.isNotEmpty&&b.isNotEmpty&&(a==b||
            (a.length>6&&b.contains(a))||(b.length>6&&a.contains(b)));
      });
      if(match==-1){out.add(p);continue;}
      final o=out[match];
      out[match]=OSMPlace(id:o.id,name:o.name,address:o.address,
          lat:o.lat,lng:o.lng,category:o.category,
          phone:o.phone,email:o.email,website:o.website,
          openingHours:o.openingHours,instagram:o.instagram,
          facebook:o.facebook,linkedin:o.linkedin,
          cuisine:o.cuisine,description:o.description,
          source:'OSM + Annuaire FR',siret:p.siret,nafCode:p.nafCode);
    }
    out.sort((a,b)=>_distance(lat,lng,a.lat,a.lng)
        .compareTo(_distance(lat,lng,b.lat,b.lng)));
    return out;
  }
  static String _name(String s)=>s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'),'');
  static double _distance(double a,double b,double c,double d){
    const r=6371000.0;final x=(c-a)*pi/180,y=(d-b)*pi/180;
    final h=sin(x/2)*sin(x/2)+cos(a*pi/180)*cos(c*pi/180)*sin(y/2)*sin(y/2);
    return r*2*atan2(sqrt(h),sqrt(max(0.0,1-h)));
  }
}
class _Entry {
  const _Entry(this.places,this.date);
  final List<OSMPlace> places;
  final DateTime date;
}
