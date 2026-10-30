import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/i18n.dart';

/// What a recipe's source link points at, by its host (short links included).
enum LinkKind { tiktok, instagram, youtube, web }

/// Null for anything that isn't an http(s) address.
LinkKind? linkKind(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !(u.scheme == 'https' || u.scheme == 'http') || u.host.isEmpty) return null;
  bool on(String domain) => u.host.toLowerCase() == domain || u.host.toLowerCase().endsWith('.$domain');
  if (on('tiktok.com')) return LinkKind.tiktok;
  if (on('instagram.com') || on('instagr.am')) return LinkKind.instagram;
  if (on('youtube.com') || on('youtu.be')) return LinkKind.youtube;
  return LinkKind.web;
}

extension LinkKindLook on LinkKind {
  String get label => switch (this) {
        LinkKind.tiktok => t('לסרטון בטיקטוק'),
        LinkKind.instagram => t('לפוסט באינסטגרם'),
        LinkKind.youtube => t('לסרטון ביוטיוב'),
        LinkKind.web => t('לאתר המקור'),
      };

  IconData get icon => this == LinkKind.web ? Icons.link : Icons.play_circle_outline;
}

const _system = MethodChannel('app/system');

/// Opens [url] in the app that owns it (TikTok, Instagram, YouTube, the to-do
/// app), else the browser. On Android as a task of its own: launched from here
/// it used to stack inside this app as well.
Future<void> openLink(String url) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      return await _system.invokeMethod<void>('openLink', url);
    } on PlatformException {
      // nothing on the phone takes it: the browser below
    }
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
