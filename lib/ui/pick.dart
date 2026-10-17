import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/i18n.dart';

/// A picked file as the server upload takes it: its bytes and its name.
typedef Picked = (List<int>, String);

XTypeGroup get _images => XTypeGroup(
    label: t('תמונות'), extensions: ['jpg', 'jpeg', 'png', 'webp', 'heic'], mimeTypes: ['image/*']);
const _pdf = XTypeGroup(label: 'PDF', extensions: ['pdf'], mimeTypes: ['application/pdf']);

bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// A photo: on Android the camera or the gallery, elsewhere a file. With
/// [pdf], a PDF may be chosen too (a scanned recipe). Null when cancelled.
Future<Picked?> pickPhoto(BuildContext context, {bool pdf = false}) async {
  if (!_android) return _file([_images, if (pdf) _pdf]);
  final how = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(t('צילום')),
            onTap: () => Navigator.pop(c, 'camera')),
        ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(t('מהגלריה')),
            onTap: () => Navigator.pop(c, 'gallery')),
        if (pdf)
          ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(t('קובץ PDF')),
              onTap: () => Navigator.pop(c, 'pdf')),
      ]),
    ),
  );
  if (how == null) return null;
  if (how == 'pdf') return _file([_pdf]);
  // A phone photo is 4 MB or more; the server needs far less to read it.
  final x = await ImagePicker().pickImage(
      source: how == 'camera' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 85);
  return x == null ? null : (await x.readAsBytes(), x.name);
}

Future<Picked?> _file(List<XTypeGroup> types) async {
  final x = await openFile(acceptedTypeGroups: types);
  return x == null ? null : (await x.readAsBytes(), x.name);
}
