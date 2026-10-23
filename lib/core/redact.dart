/// Entfernt Zugangsdaten aus Texten, bevor sie in Protokollen oder
/// Fehlermeldungen landen (z. B. `api_key=…` in Video-Adressen des Servers,
/// das Token im Authorization-Kopf oder Benutzername:Passwort in URLs).
String redactSecrets(String text) {
  var result = text;
  // Bekannte Geheimnisse (z. B. das Sitzungs-Token) überall entfernen – egal,
  // in welcher Form sie im Text stehen.
  for (final secret in _knownSecrets) {
    result = result.replaceAll(secret, '***');
  }
  return result
      .replaceAllMapped(_keyValue, (m) => '${m[1]}***')
      .replaceAllMapped(RegExp(r'(Token=")[^"]*(")', caseSensitive: false), (m) => '${m[1]}***${m[2]}')
      .replaceAllMapped(RegExp(r'(https?://)[^/\s@]+@'), (m) => '${m[1]}***@');
}

/// `api_key=…` & Co. – auch mit kodiertem Unterstrich/Bindestrich (`api%5Fkey`)
/// oder kodiertem Gleichheitszeichen (`%3D`).
final _keyValue = RegExp(
  r'((?:api(?:_|-|%5F|%2D)?key|x(?:-|%2D)(?:emby|mediabrowser)(?:-|%2D)token|access(?:_|%5F)token|token)(?:=|%3D))'
  r'[^&\s"]+',
  caseSensitive: false,
);

final _knownSecrets = <String>{};

/// Merkt sich ein Geheimnis (z. B. ein Token), damit [redactSecrets] es
/// überall entfernt. Sehr kurze Werte werden ignoriert (zu viele Treffer).
void registerSecret(String? secret) {
  if (secret != null && secret.length >= 8) _knownSecrets.add(secret);
}
