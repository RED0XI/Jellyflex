import 'package:dio/dio.dart';

/// Wiederholt Riverpod eine fehlgeschlagene Abfrage? (Ohne Vorgabe bis zu 10 Mal.)
///
/// Antworten wie "nicht angemeldet", "keine Berechtigung" oder "gibt es nicht" (4xx) ändern sich
/// durch Wiederholen nicht – die erzeugten nur sinnlose Anfragen, gerade wenn die Anmeldung
/// abgelaufen ist. Alles andere (Zeitüberschreitung, Serverfehler) höchstens dreimal, mit
/// wachsender Pause. Danach zeigt die Seite ihren Fehler mit "Erneut versuchen"; ist der
/// Server wieder da, lädt die App ohnehin neu.
Duration? providerRetry(int retryCount, Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status != null && status >= 400 && status < 500) return null;
  }
  if (retryCount >= 3) return null;
  return Duration(milliseconds: 500 * (1 << retryCount));
}
