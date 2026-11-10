// Source complementaire gratuite : Annuaire officiel (France uniquement).
// https://recherche-entreprises.api.gouv.fr/docs/
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'osm_search_service.dart';

class FrenchRegistryService {
  static final _sharedHttp=http.Client();
  final http.Client _http;
  FrenchRegistryService({http.Client? client}) : _http=client??_sharedHttp;
  static bool supportsLocation(double lat,double lng) =>
      lat>=41 && lat<=51.15 && lng>=-5.6 && lng<=9.8;

  static String? nafCodesFor(String query) {
    final parts=query.split(RegExp(r'[,;|]')).map((s)=>s.trim().toLowerCase())
        .where((s)=>s.isNotEmpty).take(6).toList();
    if (parts.isEmpty) return '';
    final codes=<String>{};var mapped=false;
    for (final p in parts) {
      final v=_naf(p);
      if (v==null) continue;
      if (v.isEmpty) return '';
      codes.addAll(v.split(','));mapped=true;
    }
    return mapped?codes.join(','):null;
  }
  static String? _naf(String q) {
    final explicit=RegExp(r'\b\d{2}\.\d{2}[a-z]\b',caseSensitive:false).firstMatch(q);
    if (explicit!=null) return explicit.group(0)!.toUpperCase();
    final wholesale=q.contains('grossiste')||q.contains('commerce de gros')||
        q.contains('négociant')||q.contains('negociant')||
        q.contains('distributeur')||q.contains('fournisseur');
    if (wholesale&&q.contains('boisson')) return '46.34Z';
    if (wholesale&&q.contains('aliment')) return
        '46.31Z,46.32A,46.32B,46.32C,46.33Z,46.36Z,46.37Z,46.38A,46.38B,46.39A,46.39B';
    if (q=='chr'||q.contains('horeca')) return '55.10Z,55.20Z,56.10A,56.10B,56.10C,56.30Z';
    if (q=='gms'||q.contains('grande surface')||q.contains('supermarket')||
        q.contains('hypermar')) return '47.11D,47.11F';
    if (q.contains('parapharm')||q.contains('drugstore')||q.contains('chemist')) return '47.75Z,47.73Z';
    if (q.contains('coif')||q.contains('barber')||q.contains('barbier')) return '96.02A';
    if (q.contains('resto')||q.contains('restaur')||q.contains('pizza')||q.contains('kebab')||
        q.contains('snack')) return '56.10A,56.10B,56.10C';
    if (q=='bar'||q.contains('cafe')||q.contains('café')) return '56.30Z,56.10A,56.10C';
    if (q.contains('hotel')||q.contains('hôtel')) return '55.10Z';
    if (q.contains('pharm')) return '47.73Z';
    if (q.contains('boulanger')) return '10.71C';
    if (q.contains('garage')) return '45.20A,45.20B';
    if (q.contains('logistique')||q.contains('logistics')||q.contains('transport')||
        q.contains('entrepôt')||q.contains('entrepot')) return '49.41A,49.41B,52.10B,52.29B';
    if (q=='tpe'||q=='pme'||q=='tpe/pme'||q=='sme'||q.contains('grand compte')||
        q.contains('large enterprise')||q.contains('small business')||q.contains('zone')||
        q.contains('parc d')||q.contains('business park')||q.contains('industrial park')) return '';
    return null;
  }

  static Uri buildUri({required double lat,required double lng,
      required int radiusMeters,required String nafCodes,int page=1,
      bool sortBySize=false}) => Uri.https('recherche-entreprises.api.gouv.fr','/near_point',{
    'lat':lat.toStringAsFixed(6),'long':lng.toStringAsFixed(6),
    'radius':(radiusMeters/1000).toStringAsFixed(2),
    'page':'$page','per_page':'25',
    if(nafCodes.isNotEmpty) 'activite_principale':nafCodes,
    if(sortBySize) 'sort_by_size':'true',
  });

  Future<List<OSMPlace>> searchNearby({required double lat,required double lng,
      required int radiusMeters,required String query}) async {
    final naf=nafCodesFor(query);
    if (!supportsLocation(lat,lng)||naf==null) return const [];
    final requestedCodes=naf.split(',').where((code)=>code.isNotEmpty).toSet();
    final big=query.toLowerCase().contains('grand compte')||
        query.toLowerCase().contains('large enterprise');
    final places=<OSMPlace>[];final seen=<String>{};
    for(var page=1;page<=2;page++) {
      final url=buildUri(lat:lat,lng:lng,radiusMeters:radiusMeters,
          nafCodes:naf,page:page,sortBySize:big);
      final res=await _http.get(url,headers:{
        'Accept':'application/json',
        'User-Agent':'Prospecto/1.6 (contact: contact@digitalsolutionsai.com)',
      }).timeout(const Duration(seconds:6));
      if(res.statusCode!=200) throw StateError('Annuaire FR HTTP ${res.statusCode}');
      final data=jsonDecode(res.body);
      if(data is! Map || data['results'] is! List) throw const FormatException('Annuaire FR');
      final companies=data['results'] as List;
      for(final raw in companies) {
        if(raw is! Map)continue;
        final company=Map<String,dynamic>.from(raw);
        if(company['etat_administratif']!='A'||company['statut_diffusion']!='O')continue;
        final matches=company['matching_etablissements'];
        final branches=matches is List && matches.isNotEmpty ? matches : [company['siege']];
        for(final branch in branches) {
          if(branch is! Map)continue;
          final e=Map<String,dynamic>.from(branch);
          if(e['etat_administratif']!='A'||e['statut_diffusion_etablissement']!='O'||
              _text(e['date_fermeture']).isNotEmpty)continue;
          // The API can return other branches of a matching company. Activity
          // and location must both belong to this branch, never its head office.
          final code=_text(e['activite_principale']).toUpperCase();
          if(requestedCodes.isNotEmpty&&!requestedCodes.contains(code))continue;
          final point=_coordinates(e);
          if(point==null||_distance(lat,lng,point.lat,point.lng)>radiusMeters)continue;
          final siret=_text(e['siret']);
          if(!RegExp(r'^\d{14}$').hasMatch(siret)||seen.contains(siret))continue;
          final labels=e['liste_enseignes'];
          final label=labels is List ? labels.map(_text).where((s)=>s.isNotEmpty).firstOrNull:'';
          final name=[label,e['nom_commercial'],company['nom_complet'],
            company['nom_raison_sociale']].map(_text).where((s)=>s.isNotEmpty).firstOrNull??'';
          if(name.isEmpty)continue;
          seen.add(siret);
          places.add(OSMPlace(
            id:'siret_$siret',name:name,
            address:_address(e),
            lat:point.lat,lng:point.lng,category:code.startsWith('56.')?'Restauration':
                code.startsWith('96.02')?'Coiffure':'Entreprise',
            source:'Annuaire des Entreprises',siret:siret,nafCode:code,
          ));
        }
      }
      final count=(data['total_pages'] as num?)?.toInt()??1;
      if(page>=count||companies.length<25)break;
    }
    return places;
  }

  static String _text(Object? value)=>value?.toString().trim()??'';

  static ({double lat,double lng})? _coordinates(Map<String,dynamic> branch) {
    ({double lat,double lng})? valid(Object? latitude,Object? longitude) {
      final lat=double.tryParse(_text(latitude));
      final lng=double.tryParse(_text(longitude));
      if(lat==null||lng==null||!lat.isFinite||!lng.isFinite||
          lat.abs()>90||lng.abs()>180)return null;
      return (lat:lat,lng:lng);
    }
    final point=valid(branch['latitude'],branch['longitude']);
    if(point!=null)return point;
    final legacy=_text(branch['coordonnees']).split(',');
    return legacy.length==2?valid(legacy[0],legacy[1]):null;
  }

  static String _address(Map<String,dynamic> branch) {
    for(final key in ['adresse','geo_adresse']) {
      final address=_text(branch[key]);
      if(address.isNotEmpty)return address;
    }
    final street=['complement_adresse','numero_voie','indice_repetition',
      'type_voie','libelle_voie'].map((key)=>_text(branch[key]))
        .where((part)=>part.isNotEmpty).join(' ');
    final city=['code_postal','libelle_commune'].map((key)=>_text(branch[key]))
        .where((part)=>part.isNotEmpty).join(' ');
    return [street,city].where((part)=>part.isNotEmpty).join(', ');
  }

  static double _distance(double a,double b,double c,double d) {
    const r=6371000.0;final x=(c-a)*pi/180;final y=(d-b)*pi/180;
    final h=sin(x/2)*sin(x/2)+cos(a*pi/180)*cos(c*pi/180)*sin(y/2)*sin(y/2);
    return r*2*atan2(sqrt(h),sqrt(max(0.0,1-h)));
  }
}
