import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/calendar/overlap_layout.dart';

void main() {
  test('重ならなければ、全部1列（幅いっぱい）', () {
    final result = layoutOverlaps(const [
      TimeRange(530, 600), // 8:50〜10:00
      TimeRange(610, 680), // 10:10〜11:20
    ]);
    expect(result, const [LayoutSlot(0, 1), LayoutSlot(0, 1)]);
  });

  test('ちょうど終わった時刻に始まるのは、重なりではない', () {
    final result = layoutOverlaps(const [
      TimeRange(960, 1020), // 16:00〜17:00
      TimeRange(1020, 1080), // 17:00〜18:00
    ]);
    expect(result, const [LayoutSlot(0, 1), LayoutSlot(0, 1)]);
  });

  test('2つが重なれば、2列に並べる', () {
    final result = layoutOverlaps(const [
      TimeRange(960, 1080), // 部活 16:00〜18:00
      TimeRange(1020, 1140), // 塾 17:00〜19:00
    ]);
    expect(result, const [LayoutSlot(0, 2), LayoutSlot(1, 2)]);
  });

  test('3つがつながって重なる場合、空いた列は使い回す', () {
    // A と B が重なり、B と C が重なる。A と C は重ならない。
    final result = layoutOverlaps(const [
      TimeRange(960, 1020), // A 16:00〜17:00
      TimeRange(990, 1080), // B 16:30〜18:00
      TimeRange(1020, 1110), // C 17:00〜18:30
    ]);
    expect(result, const [
      LayoutSlot(0, 2),
      LayoutSlot(1, 2),
      LayoutSlot(0, 2), // A が終わった列を使う
    ]);
  });

  test('入力の順番がバラバラでも、開始が早い順に考える', () {
    final result = layoutOverlaps(const [
      TimeRange(1020, 1140), // 後から始まる
      TimeRange(960, 1080), // 先に始まる
    ]);
    expect(result, const [LayoutSlot(1, 2), LayoutSlot(0, 2)]);
  });

  test('何もなければ空', () {
    expect(layoutOverlaps(const []), isEmpty);
  });
}
