import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../i18n/app_locale.dart';
import '../services/translation_service.dart';
import '../theme/app_colors.dart';

/// Caption with tappable #hashtags and highlighted @mentions.
class RichCaption extends StatefulWidget {
  final String text;
  final String? lead; // bold author name in front
  final TextStyle style;
  final int? maxLines;
  final void Function(String tag)? onHashtag;
  /// Offer "See translation" when the text is in another script from the reader's language.
  final bool translatable;
  const RichCaption(this.text, {super.key, this.lead, required this.style, this.maxLines, this.onHashtag, this.translatable = true});

  @override
  State<RichCaption> createState() => _RichCaptionState();
}

class _RichCaptionState extends State<RichCaption> {
  final List<TapGestureRecognizer> _taps = [];
  String? _translated;
  bool _showTranslation = false;
  bool _translating = false;

  @override
  void didUpdateWidget(covariant RichCaption old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _translated = null;
      _showTranslation = false;
    }
  }

  Future<void> _toggleTranslation() async {
    if (_showTranslation) return setState(() => _showTranslation = false);
    if (_translated != null) return setState(() => _showTranslation = true);
    setState(() => _translating = true);
    try {
      final t = await TranslationService.translate(widget.text);
      if (mounted) {
        setState(() {
          _translated = t;
          _showTranslation = true;
        });
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr("Couldn't translate that right now"))));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

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
    final text = _showTranslation && _translated != null ? _translated! : widget.text;
    final re = RegExp(r"([#@][\p{L}\p{N}_.]{2,40})", unicode: true);
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
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
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    final body = Text.rich(
      TextSpan(children: spans),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );
    if (!widget.translatable) return body;
    return ValueListenableBuilder<String>(
      valueListenable: TranslationService.chosen,
      builder: (context, _, _) {
        if (!_showTranslation && !TranslationService.worthOffering(widget.text)) return body;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          body,
          GestureDetector(
            onTap: _translating ? null : _toggleTranslation,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _translating ? tr("Translating…") : (_showTranslation ? tr("See original") : tr("See translation")),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.subtitle),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
