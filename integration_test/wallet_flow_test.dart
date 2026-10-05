import 'package:integration_test/integration_test.dart';
import '../test/support/wallet_flow_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerWalletFlowScenarios();
}
