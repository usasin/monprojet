import 'directory_models.dart';

String directorySearchFailureMessage(Object error, {required bool isFrench}) {
  if (error is DirectoryException) {
    final details = error.message.toLowerCase();
    if (details.contains('pack') || details.contains('annuaire local') ||
        details.contains('overpass') || details.contains('http ')) {
      return isFrench
          ? 'La recherche est temporairement indisponible. Vérifiez votre connexion puis réessayez.'
          : 'Search is temporarily unavailable. Check your connection and try again.';
    }
    return error.message;
  }
  final message = error.toString().toLowerCase();
  if (message.contains('adresse introuvable') ||
      message.contains('address not found')) {
    return isFrench
        ? 'Adresse introuvable. Ajoutez la ville, le code postal et le pays.'
        : 'Address not found. Add the city, postcode and country.';
  }
  if (message.contains('http 429')) {
    return isFrench
        ? 'Trop de requêtes. Attendez quelques secondes puis réessayez.'
        : 'Too many requests. Wait a few seconds and try again.';
  }
  if (message.contains('timeout') ||
      message.contains('timed out') ||
      message.contains('http 5')) {
    return isFrench
        ? 'Le service de recherche ne répond pas. Vérifiez la connexion puis réessayez.'
        : 'The search service is not responding. Check your connection and try again.';
  }
  return isFrench
      ? 'Connexion ou service de recherche indisponible. Aucun résultat ne peut être confirmé. Réessayez.'
      : 'Connection or search service unavailable. Results cannot be confirmed. Try again.';
}
