import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  /// Optional link (e.g. the hosted, always-current policy) shown below the
  /// content as a tappable button.
  final Uri? linkUri;
  final String? linkLabel;

  const LegalScreen({
    super.key,
    required this.title,
    required this.content,
    this.linkUri,
    this.linkLabel,
  });

  @override
  Widget build(BuildContext context) {
    final uri = linkUri;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content, style: AppTypography.body),
            if (uri != null && linkLabel != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                key: const Key('legal_screen_link'),
                icon: const Icon(Icons.open_in_new),
                label: Text(linkLabel!),
                onPressed: () async {
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    // Nothing to do if no browser is available.
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
