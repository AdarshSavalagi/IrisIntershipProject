
import 'package:flutter/material.dart';

class KeypointsPainter extends CustomPainter {
  final List<List<List<double>>> keypoints;
  final double width;
  final double height;

  KeypointsPainter({
    required this.keypoints,
    required this.width,
    required this.height,
  });
  final List<List<int>> EDGES = [
    [0, 1],
    [0, 2],
    [1, 3],
    [2, 4],
    [0, 5],
    [0, 6],
    [5, 7],
    [7, 9],
    [6, 8],
    [8, 10],
    [5, 6],
    [5, 11],
    [6, 12],
    [11, 12],
    [11, 13],
    [13, 15],
    [12, 14],
    [14, 16],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (keypoints.isEmpty) {
      return;
    }
    Paint pointPaint = Paint()..color = Colors.green;
    Paint linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2.0;

    for (var edge in EDGES) {
      int i = edge[0];
      int j = edge[1];
      double confidence1 = keypoints[0][i][2];
      double confidence2 = keypoints[0][j][2];

      if (confidence1 > 0.4 && confidence2 > 0.4) {
        connectKeypoints(canvas, i, j, linePaint, pointPaint);
      }
    }
  }

  void connectKeypoints(
      Canvas canvas, int i, int j, Paint paint, Paint pointPaint) {
    double x1 = keypoints[0][i][1] * width;
    double y1 = keypoints[0][i][0] * height;
    double x2 = keypoints[0][j][1] * width;
    double y2 = keypoints[0][j][0] * height;

    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    canvas.drawCircle(Offset(x1, y1), 3, pointPaint);
    canvas.drawCircle(Offset(x2, y2), 3, pointPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
