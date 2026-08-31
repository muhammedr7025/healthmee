import 'package:flutter/material.dart';

import '../tokens/health_colors.dart';
import 'memory_trail_painter.dart';

/// A scrollable list threaded along the Memory Trail curve — each row's dot
/// marker sits on the path, content sits to the right (Logbook, Trends).
class MemoryTrailTimeline extends StatelessWidget {
  const MemoryTrailTimeline({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.rowHeight = 84,
    this.gutterWidth = 40,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double rowHeight;
  final double gutterWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: MemoryTrailPainter(rowCount: itemCount, rowHeight: rowHeight, gutterWidth: gutterWidth),
          ),
        ),
        ListView.builder(
          itemCount: itemCount,
          itemBuilder: (context, index) {
            final markerX = MemoryTrailPainter.xAtRow(index, gutterWidth);
            return SizedBox(
              height: rowHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: gutterWidth,
                    child: Padding(
                      padding: EdgeInsets.only(left: markerX - 5, top: 6),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: HealthColors.accentTertiary, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                  Expanded(child: itemBuilder(context, index)),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
