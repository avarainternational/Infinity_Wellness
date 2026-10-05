import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:employee_wellness/wallet_sdk/src/crypto/strkey_codec.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/active_rewards_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/credential_store.dart';
import 'package:employee_wellness/wallet_sdk/src/storage/rewards_send_store.dart';

/// Only encrypted backup text crosses this private service boundary.
/// No network, clipboard, analytics, or share service receives signing material.
final class RewardsRecoveryService {
  RewardsRecoveryService(this.credentials, this.identities, this.transfers);
  final CredentialStore credentials;
  final ActiveRewardsStore identities;
  final RewardsSendStore transfers;
  static const confirmationKey = 'rewards.backup.confirmed.v1';
  static const _iterations = 210000;
  final _cipher = AesGcm.with256bits();

  Future<String> create(String password) async {
    final identity = await identities.read();
    if (identity == null) throw const FormatException();
    final secret = await credentials.read(identity.credentialKey);
    if (secret == null) throw const FormatException();
    await _verifyKey(identity, secret);
    final transfer = await transfers.read();
    _validateTransfer(identity, transfer);
    final salt = SecretKeyData.random(length: 32).bytes;
    final key = await _key(password, salt);
    final box = await _cipher.encrypt(
      utf8.encode(
        jsonEncode({
          'identity': identity.encode(),
          'secret': secret,
          'transfer': transfer?.encode(),
        }),
      ),
      secretKey: key,
      aad: utf8.encode('Builder Rewards backup v1'),
    );
    return 'BRB1.${base64Url.encode(utf8.encode(jsonEncode({'v': 1, 'salt': base64Url.encode(salt), 'nonce': base64Url.encode(box.nonce), 'cipher': base64Url.encode(box.cipherText), 'mac': base64Url.encode(box.mac.bytes)})))}';
  }

  Future<
    ({ActiveRewardsRecord identity, String secret, RewardsSendRecord? transfer})
  >
  decode(String backup, String password) async {
    if (!backup.startsWith('BRB1.') || backup.length > 24000) {
      throw const FormatException();
    }
    final json =
        jsonDecode(utf8.decode(base64Url.decode(backup.substring(5))))
            as Map<String, dynamic>;
    if (json['v'] != 1) throw const FormatException();
    final salt = base64Url.decode(json['salt'] as String);
    final nonce = base64Url.decode(json['nonce'] as String);
    final mac = base64Url.decode(json['mac'] as String);
    if (salt.length != 32 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException();
    }
    final clear = await _cipher.decrypt(
      SecretBox(
        base64Url.decode(json['cipher'] as String),
        nonce: nonce,
        mac: Mac(mac),
      ),
      secretKey: await _key(password, salt),
      aad: utf8.encode('Builder Rewards backup v1'),
    );
    final payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    final identity = ActiveRewardsRecord.decode(payload['identity'] as String);
    final secret = payload['secret'] as String;
    final transfer = payload['transfer'] == null
        ? null
        : RewardsSendRecord.decode(payload['transfer'] as String);
    await _verifyKey(identity, secret);
    _validateTransfer(identity, transfer);
    return (identity: identity, secret: secret, transfer: transfer);
  }

  Future<void> confirm(String backup, String password) async {
    final imported = await decode(backup, password);
    final current = await identities.read();
    final saved = await transfers.read();
    if (current?.encode() != imported.identity.encode() ||
        await credentials.read(imported.identity.credentialKey) !=
            imported.secret ||
        saved?.encode() != imported.transfer?.encode()) {
      throw const FormatException();
    }
    final marker = await confirmation(current!, saved);
    await credentials.write(key: confirmationKey, value: marker);
    if (await credentials.read(confirmationKey) != marker) {
      throw const FormatException();
    }
  }

  Future<String> confirmation(
    ActiveRewardsRecord identity,
    RewardsSendRecord? transfer,
  ) async {
    final hash = await Sha256().hash(
      utf8.encode('${identity.encode()}|${transfer?.encode() ?? ''}'),
    );
    return 'confirmed:${identity.accountId}:${base64Url.encode(hash.bytes)}';
  }

  Future<SecretKey> _key(String password, List<int> salt) {
    if (password.length < 12 || password.length > 256) {
      throw const FormatException();
    }
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  Future<void> _verifyKey(ActiveRewardsRecord identity, String secret) async {
    const codec = StrKeyCodec();
    final key = await Ed25519().newKeyPairFromSeed(
      codec.decodeEd25519SecretSeed(secret),
    );
    if (codec.encodeEd25519PublicKey((await key.extractPublicKey()).bytes) !=
        identity.accountId) {
      throw const FormatException();
    }
  }

  void _validateTransfer(
    ActiveRewardsRecord identity,
    RewardsSendRecord? transfer,
  ) {
    if (transfer != null &&
        (transfer.source != identity.accountId ||
            transfer.environment != identity.environment ||
            transfer.code != identity.assetCode ||
            transfer.issuer != identity.assetIssuer)) {
      throw const FormatException();
    }
  }
}
