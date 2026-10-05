import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:employee_wellness/wallet_sdk/wallet_sdk.dart';

/// SDK-owned presentation: feature controllers never hold recovery material.
class RewardsRecoveryPage extends StatefulWidget {
  const RewardsRecoveryPage({
    required this.sdk,
    required this.onChanged,
    this.messageMapper,
    super.key,
  });
  final WalletSdk sdk;
  final String Function(String)? messageMapper;
  final Future<void> Function() onChanged;
  @override
  State<RewardsRecoveryPage> createState() => _RewardsRecoveryPageState();
}

class _RewardsRecoveryPageState extends State<RewardsRecoveryPage>
    with WidgetsBindingObserver {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  final _input = TextEditingController();
  String? _backup;
  String _message = '';
  bool _busy = false;
  bool _saved = false;
  bool _removeConfirmed = false;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _password.dispose();
    _repeat.dispose();
    _input.dispose();
    _backup = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _revision++;
      _password.clear();
      _repeat.clear();
      _input.clear();
      if (mounted) {
        setState(() {
          _backup = null;
          _saved = false;
          _removeConfirmed = false;
        });
      }
    }
  }

  Future<void> _run(
    Future<String> Function() action, {
    bool changed = false,
  }) async {
    if (_busy) return;
    final revision = _revision;
    setState(() {
      _busy = true;
      _message = '';
    });
    try {
      final message = await action();
      if (!mounted || revision != _revision) return;
      setState(() => _message = message);
      if (changed) {
        _password.clear();
        _repeat.clear();
        _input.clear();
        _backup = null;
        await widget.onChanged();
      }
    } on WalletSdkException catch (error) {
      if (mounted) {
        setState(
          () => _message =
              widget.messageMapper?.call(error.safeMessage) ??
              error.safeMessage,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Check the saved backup and password. Nothing should be discarded until recovery completes.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Wellness Points backup and recovery')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Keep your backup and its password somewhere safe outside this device. Both are needed to restore your points. Wellness Admin cannot recover them for you.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Backup password',
              helperText:
                  'At least 12 characters. Keep it with your recovery records.',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repeat,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Repeat password when creating a backup',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    if (_password.text.length < 12 ||
                        _password.text != _repeat.text) {
                      return 'Enter matching passwords of at least 12 characters.';
                    }
                    final revision = _revision;
                    final backup = await widget.sdk.createRewardsBackup(
                      _password.text,
                    );
                    if (mounted && revision == _revision) {
                      setState(() => _backup = backup);
                    }
                    return 'Save the complete encrypted text below outside this device. Then paste your saved copy below and verify it.';
                  }),
            child: const Text('Back up Wellness Points'),
          ),
          if (_backup != null) ...[
            const SizedBox(height: 12),
            const Text('Your encrypted backup'),
            Text(_backup!),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final backup = _backup;
                      if (backup == null) return;
                      try {
                        await Clipboard.setData(ClipboardData(text: backup));
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _message =
                                'The encrypted backup could not be copied. Keep this device and try again.',
                          );
                        }
                        return;
                      }
                      if (mounted) {
                        setState(
                          () => _message =
                              'Encrypted backup copied. Save it outside this device, then paste the saved copy below to verify. Keep the password too.',
                        );
                      }
                    },
              icon: const Icon(Icons.copy),
              label: const Text('Copy encrypted backup'),
            ),
          ],
          const SizedBox(height: 18),
          TextField(
            controller: _input,
            enabled: !_busy,
            minLines: 3,
            maxLines: 6,
            maxLength: 24000,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Paste your saved encrypted backup',
              hintText: 'BRB1.…',
            ),
          ),
          CheckboxListTile(
            value: _saved,
            onChanged: _busy
                ? null
                : (value) => setState(() => _saved = value ?? false),
            title: const Text(
              'I saved the backup and password outside this device',
            ),
          ),
          OutlinedButton(
            onPressed: _busy || !_saved
                ? null
                : () => _run(() async {
                    await widget.sdk.confirmRewardsBackup(
                      _input.text,
                      _password.text,
                    );
                    return 'Backup verified for this account. You can restore it using this text and password.';
                  }),
            child: const Text('Verify saved backup'),
          ),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(() async {
                    await widget.sdk.restoreRewardsBackup(
                      _input.text,
                      _password.text,
                    );
                    return 'Wellness Points restored. Request service settings from Wellness Admin if needed.';
                  }, changed: true),
            child: const Text('Restore Wellness Points'),
          ),
          const Divider(height: 32),
          const Text(
            'Remove from this device deletes its signing key. It does not delete your account or points. You will need your verified backup to return. Pending transfers must be resolved first.',
          ),
          CheckboxListTile(
            value: _removeConfirmed,
            onChanged: _busy
                ? null
                : (value) => setState(() => _removeConfirmed = value ?? false),
            title: const Text(
              'I understand and want to remove credentials from this device',
            ),
          ),
          OutlinedButton(
            onPressed: _busy || !_removeConfirmed
                ? null
                : () => _run(() async {
                    await widget.sdk.eraseRewardsFromDevice();
                    return 'Removed from this device. Keep your backup to restore Wellness Points.';
                  }, changed: true),
            child: const Text('Remove from this device'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_message),
            ),
        ],
      ),
    ),
  );
}
