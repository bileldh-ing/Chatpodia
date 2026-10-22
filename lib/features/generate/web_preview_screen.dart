import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../chat/widgets/message_bubble.dart' show showGlassToast;

/// Runs a generated single-file web app in a sandboxed WebView, with code view.
class WebPreviewScreen extends StatefulWidget {
  const WebPreviewScreen({super.key, required this.html, required this.title});
  final String html;
  final String title;

  @override
  State<WebPreviewScreen> createState() => _WebPreviewScreenState();
}

class _WebPreviewScreenState extends State<WebPreviewScreen> {
  late final WebViewController _web = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(const Color(0xFF0B1C22))
    ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) {
      if (mounted) setState(() => _loading = false);
    }))
    ..loadHtmlString(widget.html);
  bool _code = false;
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        layout: GlowLayout.chat,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Row(children: [
                  GlassIconButton(
                      icon: Icons.chevron_left_rounded, iconSize: 24, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 15)),
                  ),
                  GlassIconButton(
                    icon: _code ? Icons.visibility_rounded : Icons.code_rounded,
                    onTap: () => setState(() => _code = !_code),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(icon: Icons.refresh_rounded, onTap: () => _web.loadHtmlString(widget.html)),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.ios_share_rounded,
                    onTap: () => SharePlus.instance.share(ShareParams(text: widget.html, subject: widget.title)),
                  ),
                ]),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _code
                          ? Container(
                              key: const ValueKey('code'),
                              color: const Color(0xFF071012),
                              child: Stack(children: [
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(14),
                                  child: SelectableText(widget.html,
                                      style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11.5,
                                          color: AppColors.mintSoft,
                                          height: 1.4)),
                                ),
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: GlassChip(
                                    icon: Icons.copy_rounded,
                                    label: 'Copy',
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: widget.html));
                                      showGlassToast(context, 'Code copied');
                                    },
                                  ),
                                ),
                              ]),
                            )
                          : Stack(key: const ValueKey('web'), children: [
                              WebViewWidget(controller: _web),
                              if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.mint)),
                            ]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
