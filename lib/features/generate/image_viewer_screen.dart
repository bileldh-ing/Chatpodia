import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/liquid_glass.dart';

/// Full-screen, pinch-to-zoom image viewer with glass controls.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.url, required this.prompt});
  final String url;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withValues(alpha: 0.75)),
          ),
          GestureDetector(
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0).abs() > 600) Navigator.of(context).pop();
            },
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(child: Hero(tag: url, child: Image(image: appImage(url), fit: BoxFit.contain))),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(children: [
                    GlassIconButton(icon: Icons.close_rounded, onTap: () => Navigator.of(context).pop()),
                    const Spacer(),
                    GlassIconButton(
                        icon: Icons.download_rounded,
                        tooltip: 'Open / save',
                        onTap: url.startsWith('http')
                            ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                            : null),
                    const SizedBox(width: 10),
                    GlassIconButton(
                        icon: Icons.ios_share_rounded,
                        onTap: () => SharePlus.instance.share(ShareParams(text: '$prompt\n$url'))),
                  ]),
                  const Spacer(),
                  LiquidGlass(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.mint),
                      const SizedBox(width: 8),
                      Expanded(child: Text(prompt, style: AppText.small, maxLines: 3, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
