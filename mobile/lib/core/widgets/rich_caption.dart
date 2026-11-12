import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Caption with tappable #hashtags and highlighted @mentions.
class RichCaption extends StatefulWidget {
  final String text;
  final String? lead; // bold author name in front
  final TextStyle style;
  final int? maxLines;
  final void Function(String tag)? onHashtag;
  const RichCaption(this.text, {super.key, this.lead, required this.style, this.maxLines, this.onHashtag});

  @override
  State<RichCaption> createState() => _RichCaptionState();
}

class _RichCaptionState extends State<RichCaption> {
  final List<TapGestureRecognizer> _taps = [];

  @override
  void dispose() {
    for (final t in _taps) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final t in _taps) {
      t.dispose();
    }
    _taps.clear();
    final spans = <InlineSpan>[];
    if (widget.lead != null) spans.add(TextSpan(text: "${widget.lead}  ", style: const TextStyle(fontWeight: FontWeight.w800)));
    final re = RegExp(r"([#@][\p{L}\p{N}_.]{2,40})", unicode: true);
    var last = 0;
    for (final m in re.allMatches(widget.text)) {
      if (m.start > last) spans.add(TextSpan(text: widget.text.substring(last, m.start)));
      final token = m.group(0)!;
      if (token.startsWith("#")) {
        final tap = TapGestureRecognizer()..onTap = () => widget.onHashtag?.call(token.substring(1).toLowerCase());
        _taps.add(tap);
        spans.add(TextSpan(text: token, style: const TextStyle(color: Color(0xFF1D6FD1), fontWeight: FontWeight.w700), recognizer: tap));
      } else {
        spans.add(TextSpan(text: token, style: const TextStyle(color: AppColors.joy, fontWeight: FontWeight.w700)));
      }
      last = m.end;
    }
    if (last < widget.text.length) spans.add(TextSpan(text: widget.text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
