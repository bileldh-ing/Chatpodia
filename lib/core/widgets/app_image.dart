import 'dart:io';

import 'package:flutter/widgets.dart';

/// Resolves network URLs, `asset:` paths and local files to an ImageProvider.
ImageProvider appImage(String src) {
  if (src.startsWith('http://') || src.startsWith('https://')) return NetworkImage(src);
  if (src.startsWith('asset:')) return AssetImage(src.substring(6));
  return FileImage(File(src));
}
