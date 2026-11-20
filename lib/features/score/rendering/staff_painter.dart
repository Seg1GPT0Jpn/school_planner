/// 五線譜を描く CustomPainter
library;

import 'package:material_ui/material_ui.dart';

import '../model/clef.dart';
import '../model/duration.dart';
import '../model/key_signature.dart';
import '../model/pitch.dart';
import '../model/score.dart';
import 'staff_layout.dart';

/// 調号の♯・♭を五線のどの高さに置くか（音部記号ごと・幹音ごとの固定の並び。
/// 楽譜の慣習どおりの位置）
const Map<Clef, Map<int, int>> _sharpPositions = {
  Clef.treble: {3: 10, 0: 7, 4: 11, 1: 8, 5: 5, 2: 9, 6: 6},
  Clef.bass: {3: 3, 0: 0, 4: 4, 1: 1, 5: -2, 2: 2, 6: -1},
};
const Map<Clef, Map<int, int>> _flatPositions = {
  Clef.treble: {6: 6, 2: 9, 5: 5, 1: 8, 4: 4, 0: 7, 3: 10},
  Clef.bass: {6: -1, 2: 2, 5: -2, 1: 1, 4: -3, 0: 0, 3: 3},
};

/// 五線譜1段（1パートぶん）を描く
class StaffPainter extends CustomPainter {
  StaffPainter({
    required this.part,
    required this.layout,
    this.selected,
    this.lineSpacing = 10,
    this.staffTop = 30,
    Color? lineColor,
    Color? noteColor,
    Color? selectedColor,
  }) : lineColor = lineColor ?? Colors.black87,
       noteColor = noteColor ?? Colors.black,
       selectedColor = selectedColor ?? Colors.blue;

  final ScorePart part;
  final PartLayout layout;

  /// 選択中の音符（measureIndex, noteIndex）。null なら選択なし
  final (int, int)? selected;

  final double lineSpacing;
  final double staffTop;
  final Color lineColor;
  final Color noteColor;
  final Color selectedColor;

  double get _staffBottom => staffTop + lineSpacing * 4;

  /// [Pitch.staffStep] から、実際のy座標を求める
  double yForStaffStep(int staffStep) {
    final bottomStep = part.clef.bottomLineStaffStep;
    return _staffBottom - (staffStep - bottomStep) * (lineSpacing / 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawStaffLines(canvas);
    _drawClef(canvas);
    _drawKeySignature(canvas);
    _drawTimeSignature(canvas);
    _drawBarlines(canvas);
    _drawNotes(canvas);
  }

  void _drawStaffLines(Canvas canvas) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      final y = staffTop + lineSpacing * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(layout.contentWidth, y),
        paint,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    double fontSize = 16,
    Color? color,
    FontWeight weight = FontWeight.normal,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color ?? noteColor,
          fontWeight: weight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  void _drawClef(Canvas canvas) {
    // SMuFL専用フォントを入れていないので、Unicodeの音楽記号で代用する
    // （フェーズ4で専用フォントに差し替え予定）
    final symbol = part.clef == Clef.treble ? '\u{1D11E}' : '\u{1D122}';
    final centerStep = part.clef.bottomLineStaffStep + 4; // 五線の真ん中あたり
    _drawText(
      canvas,
      symbol,
      Offset(layout.clefX, yForStaffStep(centerStep)),
      fontSize: lineSpacing * 4.4,
    );
  }

  void _drawKeySignature(Canvas canvas) {
    final fifths = part.keySignature.fifths;
    if (fifths == 0) return;
    final positions = fifths > 0
        ? _sharpPositions[part.clef]!
        : _flatPositions[part.clef]!;
    final order = fifths > 0
        ? KeySignature.sharpOrderForDrawing
        : KeySignature.flatOrderForDrawing;
    final symbol = fifths > 0 ? '♯' : '♭';
    final count = fifths.abs();
    var x = layout.keySigStartX;
    for (var i = 0; i < count; i++) {
      final step = order[i];
      final staffStep = positions[step]!;
      _drawText(
        canvas,
        symbol,
        Offset(x, yForStaffStep(staffStep)),
        fontSize: lineSpacing * 1.9,
      );
      x += lineSpacing * 1.1;
    }
  }

  void _drawTimeSignature(Canvas canvas) {
    final x = layout.timeSigX;
    final middle = part.clef == Clef.treble ? 6 : -6;
    _drawText(
      canvas,
      '${part.timeSignature.numerator}',
      Offset(x, yForStaffStep(middle + 2)),
      fontSize: lineSpacing * 2.0,
      weight: FontWeight.bold,
    );
    _drawText(
      canvas,
      '${part.timeSignature.denominator}',
      Offset(x, yForStaffStep(middle - 2)),
      fontSize: lineSpacing * 2.0,
      weight: FontWeight.bold,
    );
  }

  void _drawBarlines(Canvas canvas) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2;
    for (final m in layout.measures) {
      canvas.drawLine(
        Offset(m.endX, staffTop),
        Offset(m.endX, _staffBottom),
        paint,
      );
    }
  }

  void _drawLedgerLines(Canvas canvas, double centerX, int staffStep) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.2;
    const halfWidth = 9.0;
    final topStep = part.clef.bottomLineStaffStep + 8;
    final bottomStep = part.clef.bottomLineStaffStep;
    if (staffStep > topStep) {
      var step = topStep + 2;
      while (step <= staffStep) {
        final y = yForStaffStep(step);
        canvas.drawLine(
          Offset(centerX - halfWidth, y),
          Offset(centerX + halfWidth, y),
          paint,
        );
        step += 2;
      }
    } else if (staffStep < bottomStep) {
      var step = bottomStep - 2;
      while (step >= staffStep) {
        final y = yForStaffStep(step);
        canvas.drawLine(
          Offset(centerX - halfWidth, y),
          Offset(centerX + halfWidth, y),
          paint,
        );
        step -= 2;
      }
    }
  }

  void _drawNotes(Canvas canvas) {
    for (final slot in layout.notes) {
      final isSelected =
          selected != null &&
          selected!.$1 == slot.measureIndex &&
          selected!.$2 == slot.noteIndex;
      final color = isSelected ? selectedColor : noteColor;
      if (slot.note.isRest) {
        _drawRest(canvas, slot, color);
      } else {
        _drawNoteHeadsAndStem(canvas, slot, color);
      }
    }
  }

  void _drawRest(Canvas canvas, NoteSlot slot, Color color) {
    final paint = Paint()..color = color;
    final middleStep = part.clef.bottomLineStaffStep + 4;
    final x = slot.centerX;
    switch (slot.note.duration.base) {
      case NoteDurationBase.whole:
        final y = yForStaffStep(middleStep + 2);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 12, height: 5),
          paint,
        );
        break;
      case NoteDurationBase.half:
        final y = yForStaffStep(middleStep);
        canvas.drawRect(
          Rect.fromCenter(center: Offset(x, y), width: 12, height: 5),
          paint,
        );
        break;
      case NoteDurationBase.quarter:
        _drawQuarterRest(canvas, x, yForStaffStep(middleStep), color);
        break;
      case NoteDurationBase.eighth:
      case NoteDurationBase.sixteenth:
      case NoteDurationBase.thirtySecond:
        _drawFlaggedRest(canvas, slot, x, yForStaffStep(middleStep), color);
        break;
    }
    _drawDots(canvas, slot, x + 14, yForStaffStep(middleStep), color);
  }

  void _drawQuarterRest(Canvas canvas, double x, double y, Color color) {
    // 4分休符：簡略化したジグザグ（本来の書体ではなく、判別できる簡易な形）
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(x - 3, y - 10)
      ..lineTo(x + 3, y - 3)
      ..lineTo(x - 4, y + 2)
      ..lineTo(x + 3, y + 7)
      ..lineTo(x - 3, y + 12);
    canvas.drawPath(path, paint);
  }

  void _drawFlaggedRest(
    Canvas canvas,
    NoteSlot slot,
    double x,
    double y,
    Color color,
  ) {
    final flagCount = switch (slot.note.duration.base) {
      NoteDurationBase.eighth => 1,
      NoteDurationBase.sixteenth => 2,
      NoteDurationBase.thirtySecond => 3,
      _ => 1,
    };
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y - 9), Offset(x - 5, y + 9), paint);
    for (var i = 0; i < flagCount; i++) {
      final oy = y - 8 + i * 6.0;
      final path = Path()
        ..moveTo(x, oy)
        ..quadraticBezierTo(x + 8, oy + 3, x + 2, oy + 9);
      canvas.drawPath(path, paint);
    }
  }

  void _drawDots(Canvas canvas, NoteSlot slot, double x, double y, Color color) {
    if (slot.note.duration.dots == 0) return;
    final paint = Paint()..color = color;
    for (var i = 0; i < slot.note.duration.dots; i++) {
      canvas.drawCircle(Offset(x + i * 7, y), 1.8, paint);
    }
  }

  void _drawNoteHeadsAndStem(Canvas canvas, NoteSlot slot, Color color) {
    final note = slot.note;
    final isOpen = note.duration.base == NoteDurationBase.whole ||
        note.duration.base == NoteDurationBase.half;
    final headPaint = Paint()
      ..color = color
      ..style = isOpen ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1.6;

    final steps = note.pitches.map((p) => p.staffStep).toList();
    final minStep = steps.reduce((a, b) => a < b ? a : b);
    final maxStep = steps.reduce((a, b) => a > b ? a : b);
    final middleStep = part.clef.bottomLineStaffStep + 4;
    final stemUp = maxStep < middleStep + 1;

    for (final step in steps) {
      final y = yForStaffStep(step);
      _drawLedgerLines(canvas, slot.centerX, step);
      canvas.save();
      canvas.translate(slot.centerX, y);
      canvas.rotate(-0.2);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 10.4, height: 7.6),
        headPaint,
      );
      canvas.restore();
    }

    if (note.duration.base != NoteDurationBase.whole) {
      final stemPaint = Paint()
        ..color = color
        ..strokeWidth = 1.5;
      final headStep = stemUp ? minStep : maxStep;
      final headY = yForStaffStep(headStep);
      final stemLength = lineSpacing * 3.5;
      final stemX = slot.centerX + (stemUp ? 4.8 : -4.8);
      final stemEndY = stemUp ? headY - stemLength : headY + stemLength;
      canvas.drawLine(Offset(stemX, headY), Offset(stemX, stemEndY), stemPaint);

      final flagCount = switch (note.duration.base) {
        NoteDurationBase.eighth => 1,
        NoteDurationBase.sixteenth => 2,
        NoteDurationBase.thirtySecond => 3,
        _ => 0,
      };
      for (var i = 0; i < flagCount; i++) {
        final fy = stemUp ? stemEndY + i * 7.0 : stemEndY - i * 7.0;
        final path = Path()..moveTo(stemX, fy);
        if (stemUp) {
          path.quadraticBezierTo(stemX + 10, fy + 4, stemX + 3, fy + 12);
        } else {
          path.quadraticBezierTo(stemX - 10, fy - 4, stemX - 3, fy - 12);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // 臨時記号（調号にない変化のとき）
    for (final p in note.pitches) {
      if (p.alter != 0) {
        _drawText(
          canvas,
          p.alterSymbol,
          Offset(slot.centerX - 13, yForStaffStep(p.staffStep)),
          fontSize: lineSpacing * 1.8,
          color: color,
        );
      }
    }

    _drawDots(
      canvas,
      slot,
      slot.centerX + 10,
      yForStaffStep((minStep + maxStep) ~/ 2),
      color,
    );

    if (note.tiedToNext) {
      final y = yForStaffStep(maxStep) - lineSpacing;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      final path = Path()
        ..moveTo(slot.centerX, y)
        ..quadraticBezierTo(
          slot.centerX + slot.width / 2,
          y - 6,
          slot.centerX + slot.width,
          y,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant StaffPainter oldDelegate) {
    return oldDelegate.part != part ||
        oldDelegate.selected != selected ||
        oldDelegate.layout != layout;
  }
}
