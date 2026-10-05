import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/protocol/rewards_amount.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

enum RewardsSendStatus { submitting, uncertain, confirmed, failed, cancelled }

final class RewardsSendRecord {
  const RewardsSendRecord({
    required this.reviewId,
    required this.hash,
    required this.source,
    required this.recipient,
    required this.environment,
    required this.code,
    required this.issuer,
    required this.amount,
    required this.fee,
    required this.sequence,
    required this.maxTime,
    required this.status,
    this.resolution,
  });
  final String reviewId,
      hash,
      source,
      recipient,
      code,
      issuer,
      amount,
      sequence;
  final ProviderEnvironment environment;
  final int fee, maxTime;
  final RewardsSendStatus status;
  final String? resolution;
  bool get isPending =>
      status == RewardsSendStatus.submitting ||
      status == RewardsSendStatus.uncertain;
  RewardsSendRecord withStatus(RewardsSendStatus value, {String? proof}) =>
      RewardsSendRecord(
        reviewId: reviewId,
        hash: hash,
        source: source,
        recipient: recipient,
        environment: environment,
        code: code,
        issuer: issuer,
        amount: amount,
        fee: fee,
        sequence: sequence,
        maxTime: maxTime,
        status: value,
        resolution: proof ?? resolution,
      );
  void validate() {
    if (resolution != null && (resolution!.length > 512 || isPending)) {
      throw const FormatException('Invalid resolution evidence.');
    }
    const codec = StrKeyCodec();
    for (final value in <String>[source, recipient, issuer]) {
      codec.decodeEd25519PublicKey(value);
    }
    if (!RegExp(r'^SEND-[A-Z0-9]{24}$').hasMatch(reviewId) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        !RegExp(r'^[A-Za-z0-9]{1,12}$').hasMatch(code) ||
        RewardsAmount.parse(amount) <= BigInt.zero ||
        fee <= 0 ||
        fee > 0xffffffff ||
        maxTime <= 0 ||
        maxTime > 0xffffffff ||
        !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(sequence) ||
        BigInt.parse(sequence) > RewardsAmount.maximum) {
      throw const FormatException('Invalid transfer evidence.');
    }
  }

  String encode() {
    validate();
    return jsonEncode(<String, Object>{
      'version': 1,
      'review': reviewId,
      'hash': hash,
      'source': source,
      'recipient': recipient,
      'environment': environment.name,
      'code': code,
      'issuer': issuer,
      'amount': amount,
      'fee': fee,
      'sequence': sequence,
      'max_time': maxTime,
      'status': status.name,
      if (resolution != null) 'resolution': resolution!,
    });
  }

  factory RewardsSendRecord.decode(String raw) {
    if (raw.length > 4096) {
      throw const FormatException('Transfer evidence too large.');
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    if (data['version'] != 1) {
      throw const FormatException('Unsupported transfer evidence.');
    }
    final record = RewardsSendRecord(
      reviewId: data['review'] as String,
      hash: data['hash'] as String,
      source: data['source'] as String,
      recipient: data['recipient'] as String,
      environment: ProviderEnvironment.values.byName(
        data['environment'] as String,
      ),
      code: data['code'] as String,
      issuer: data['issuer'] as String,
      amount: data['amount'] as String,
      fee: data['fee'] as int,
      sequence: data['sequence'] as String,
      maxTime: data['max_time'] as int,
      status: RewardsSendStatus.values.byName(data['status'] as String),
      resolution: data['resolution'] as String?,
    );
    record.validate();
    return record;
  }
}

abstract interface class RewardsSendStore {
  Future<RewardsSendRecord?> read();
  Future<void> write(RewardsSendRecord record);
}

final class ProtectedRewardsSendStore implements RewardsSendStore {
  ProtectedRewardsSendStore({FlutterSecureStorage? secureStorage})
    : _storage = secureStorage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const String key = 'rewards.send.evidence.v1';
  @override
  Future<RewardsSendRecord?> read() async {
    final String? raw = await _storage.read(key: key);
    return raw == null ? null : RewardsSendRecord.decode(raw);
  }

  @override
  Future<void> write(RewardsSendRecord record) async {
    final String raw = record.encode();
    await _storage.write(key: key, value: raw);
    if (await _storage.read(key: key) != raw) {
      throw StateError('Transfer evidence was not persisted.');
    }
  }
}
