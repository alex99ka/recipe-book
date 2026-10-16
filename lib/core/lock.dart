import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Fingerprint (Windows Hello on the PC) sign-in, opt-in. The app always stays
/// signed in and never asks on opening: a recipe book isn't that private, and
/// a lock at every visit gets in the way of cooking. When this is on, "יציאה"
/// only puts the app behind the fingerprint, and signing back in is a touch
/// instead of Google (the device PIN as the fallback). A failed fingerprint
/// never signs out; "כניסה עם Google" there does a real sign-out.

const _onKey = 'fingerprint_lock';
const _outKey = 'fingerprint_signed_out';
const _system = MethodChannel('app/system');

/// Signed out with the fingerprint on: the app waits behind the fingerprint.
final fingerprintSignedOut = ValueNotifier<bool>(false);

/// "יציאה" with the fingerprint on: the session stays, the app locks.
Future<void> signOutToFingerprint() async {
  await (await SharedPreferences.getInstance()).setBool(_outKey, true);
  fingerprintSignedOut.value = true;
}

Future<void> _clearSignedOut() async {
  await (await SharedPreferences.getInstance()).setBool(_outKey, false);
  fingerprintSignedOut.value = false;
}

enum FingerprintResult { enabled, cancelled, unsupported }

/// null where the device can't do it (or on the web); otherwise on/off.
Future<bool?> fingerprintSetting() async {
  if (kIsWeb) return null;
  try {
    if (!await LocalAuthentication().isDeviceSupported()) return null;
    return (await SharedPreferences.getInstance()).getBool(_onKey) ?? false;
  } catch (_) {
    return null;
  }
}

Future<void> disableFingerprint() async {
  await (await SharedPreferences.getInstance()).setBool(_onKey, false);
  await _clearSignedOut();
}

/// Turns the lock on the way the phone expects: if no fingerprint is enrolled
/// yet, the phone's own enrollment screen opens, and this continues when the
/// user comes back. Then the system prompt confirms it once.
Future<FingerprintResult> enableFingerprint() async {
  final auth = LocalAuthentication();
  if (!await auth.isDeviceSupported()) return FingerprintResult.unsupported;
  if ((await auth.getAvailableBiometrics()).isEmpty &&
      defaultTargetPlatform == TargetPlatform.android) {
    final back = Completer<void>();
    final listener = AppLifecycleListener(onResume: () {
      if (!back.isCompleted) back.complete();
    });
    try {
      await _system.invokeMethod('enrollBiometrics');
      await back.future.timeout(const Duration(minutes: 10));
    } on TimeoutException {
      return FingerprintResult.cancelled;
    } finally {
      listener.dispose();
    }
    if ((await auth.getAvailableBiometrics()).isEmpty) {
      return FingerprintResult.cancelled;
    }
  }
  try {
    final ok = await auth.authenticate(
      localizedReason: 'אישור כניסה בטביעת אצבע ל${AppConfig.name}',
      persistAcrossBackgrounding: true,
    );
    if (!ok) return FingerprintResult.cancelled;
  } on LocalAuthException {
    return FingerprintResult.cancelled;
  }
  await (await SharedPreferences.getInstance()).setBool(_onKey, true);
  return FingerprintResult.enabled;
}

class AppLock extends StatefulWidget {
  const AppLock({super.key, required this.signedIn, required this.signOut, required this.child});

  /// Nothing to lock on the sign-in screen.
  final bool Function() signedIn;

  /// The real sign-out, for "כניסה עם Google" on the lock.
  final Future<void> Function() signOut;
  final Widget child;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> {
  bool _locked = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    fingerprintSignedOut.addListener(_onSignedOut);
    // Signed out with the fingerprint last time: still behind it after a restart.
    SharedPreferences.getInstance().then((p) {
      if (p.getBool(_outKey) ?? false) fingerprintSignedOut.value = true;
    });
  }

  @override
  void dispose() {
    fingerprintSignedOut.removeListener(_onSignedOut);
    super.dispose();
  }

  void _onSignedOut() {
    if (fingerprintSignedOut.value) _lock();
  }

  Future<void> _lock() async {
    if (!widget.signedIn() || await fingerprintSetting() != true) {
      await _clearSignedOut(); // nothing to come back to by fingerprint
      return;
    }
    if (!mounted) return;
    setState(() => _locked = true);
  }

  Future<void> _google() async {
    await _clearSignedOut();
    await widget.signOut();
    if (mounted) setState(() => _locked = false);
  }

  Future<void> _unlock() async {
    if (_asking) return;
    _asking = true;
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'פתיחת ${AppConfig.name}',
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        await _clearSignedOut();
        if (mounted) setState(() => _locked = false);
      }
    } on LocalAuthException catch (e) {
      // The fingerprint was removed from the phone: don't lock anyone out.
      if (e.code == LocalAuthExceptionCode.noCredentialsSet ||
          e.code == LocalAuthExceptionCode.noBiometricHardware) {
        await disableFingerprint();
        await _google();
      }
      // Cancelled or too many tries: the button below retries.
    } finally {
      _asking = false;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child, // keeps its state under the lock
          if (_locked)
            Positioned.fill(
              child: Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(AppConfig.name,
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 40),
                      FilledButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('כניסה בטביעת אצבע'),
                      ),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _google, child: const Text('כניסה עם Google')),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
}
