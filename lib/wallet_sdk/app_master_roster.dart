import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

enum BuilderAccessState { pending, active, suspended }

final class BuilderAccessEntry {
  const BuilderAccessEntry({
    required this.id,
    required this.displayName,
    required this.state,
    required this.updatedAt,
    this.publicAccount,
    this.rewardsBalance,
  });
  final String id;
  final String displayName;
  final BuilderAccessState state;
  final DateTime updatedAt;
  final String? publicAccount;
  final String? rewardsBalance;
}

final class AppMasterRosterQuery {
  const AppMasterRosterQuery({
    required this.environment,
    required this.authorityAccount,
    required this.limit,
    this.cursor,
  });
  final ProviderEnvironment environment;
  final String authorityAccount;
  final int limit;
  final String? cursor;
}

final class AppMasterRosterPage {
  AppMasterRosterPage({
    required this.environment,
    required this.authorityAccount,
    required List<BuilderAccessEntry> entries,
    required this.observedAt,
    this.nextCursor,
  }) : entries = List<BuilderAccessEntry>.unmodifiable(entries);
  final ProviderEnvironment environment;
  final String authorityAccount;
  final List<BuilderAccessEntry> entries;
  final DateTime observedAt;
  final String? nextCursor;
}
