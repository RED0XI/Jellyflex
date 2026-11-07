// Treiber für `flutter drive` (Messungen im Profile-Modus auf echten Geräten).
// Die Werte aus `binding.reportData` landen in build/integration_response_data.json.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
