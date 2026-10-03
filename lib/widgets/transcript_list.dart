import 'package:flutter/material.dart';

import '../demo/simulator.dart';
import '../lang.dart';
import '../theme.dart';

/// Live transcript bubbles; danger lines glow red, safe lines stay neutral.
class TranscriptList extends StatefulWidget {
  final List<TranscriptLine> lines;
  const TranscriptList({super.key, required this.lines});

  @override
  State<TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<TranscriptList> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant TranscriptList old) {
    super.didUpdateWidget(old);
    if (widget.lines.length != old.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) {
          _controller.animateTo(
            _controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            context.tr('transcriptEmpty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: KavachColors.sub, fontSize: 14, height: 1.6),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _controller,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: widget.lines.length,
      itemBuilder: (context, i) {
        final line = widget.lines[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: line.flagged
                ? KavachColors.tintForLevel(RiskLevel.danger)
                : KavachColors.surface2.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: line.flagged
                  ? KavachColors.danger.withValues(alpha: 0.5)
                  : KavachColors.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                line.flagged
                    ? Icons.warning_amber_rounded
                    : Icons.mic_none_rounded,
                size: 18,
                color: line.flagged
                    ? KavachColors.danger
                    : KavachColors.sub,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  line.text,
                  style:
                      const TextStyle(fontSize: 14.5, height: 1.45),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
