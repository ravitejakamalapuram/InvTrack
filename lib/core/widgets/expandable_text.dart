/// Text cut to [maxLines] with a "Read more" / "Show less" toggle, shown only
/// when the text does not fit. See design/system/components/DailyTipCard.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.style, this.maxLines = 3});

  final String text;
  final TextStyle? style;
  final int maxLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  void didUpdateWidget(ExpandableText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final style = widget.style ?? theme.textTheme.bodySmall;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (overflows)
              Semantics(
                button: true,
                label: _expanded
                    ? l10n.expandableTextLess
                    : l10n.expandableTextMore,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ExcludeSemantics(
                        child: Text(
                          _expanded
                              ? l10n.expandableTextLess
                              : l10n.expandableTextMore,
                          style: style?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
