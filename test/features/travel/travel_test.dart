import 'package:flutter_test/flutter_test.dart';
import 'package:school_planner/features/settings/app_settings.dart';
import 'package:school_planner/features/travel/geocoder.dart';
import 'package:school_planner/features/travel/travel.dart';

void main() {
  const fujisawaSt = LatLng(35.3387, 139.4875); // 藤沢駅のあたり
  const yokohamaSt = LatLng(35.4658, 139.6223); // 横浜駅のあたり

  group('距離', () {
    test('藤沢〜横浜はまっすぐ約18km', () {
      final km = distanceKm(fujisawaSt, yokohamaSt);
      expect(km, greaterThan(17));
      expect(km, lessThan(20));
    });

    test('同じ場所は0km', () {
      expect(distanceKm(fujisawaSt, fujisawaSt), 0);
    });
  });

  group('かかる時間の目安', () {
    test('5分単位に切り上げる', () {
      for (final km in [0.5, 1.0, 3.0, 8.0, 18.0]) {
        for (final mode in TravelMode.values) {
          expect(estimateTravelMinutes(km, mode) % 5, 0);
          expect(estimateTravelMinutes(km, mode), greaterThanOrEqualTo(5));
        }
      }
    });

    test('近いときは歩き', () {
      expect(walkingIsFaster(0.5, TravelMode.transit), isTrue);
      expect(walkingIsFaster(8, TravelMode.transit), isFalse);
    });

    test('遠いほど時間がかかる', () {
      expect(
        estimateTravelMinutes(18, TravelMode.transit),
        greaterThan(estimateTravelMinutes(5, TravelMode.transit)),
      );
    });

    test('18km を電車・バスで：おおよそ1時間', () {
      final m = estimateTravelMinutes(18, TravelMode.transit);
      expect(m, inInclusiveRange(55, 75));
    });
  });

  group('出発時刻', () {
    test('開始時刻 −（移動＋余裕）', () {
      final plan = planTravel(
        from: fujisawaSt,
        to: yokohamaSt,
        arriveBy: DateTime(2026, 9, 26, 14, 0),
        origin: TravelOrigin.home,
        mode: TravelMode.transit,
        bufferMinutes: 10,
      )!;
      expect(
        plan.departAt,
        DateTime(
          2026,
          9,
          26,
          14,
          0,
        ).subtract(Duration(minutes: plan.minutes + 10)),
      );
    });

    test('すぐ近くなら計画は作らない', () {
      expect(
        planTravel(
          from: fujisawaSt,
          to: const LatLng(35.3388, 139.4876),
          arriveBy: DateTime(2026, 9, 26, 14),
          origin: TravelOrigin.home,
          mode: TravelMode.transit,
        ),
        isNull,
      );
    });

    test('授業のあとに始まる予定は学校から', () {
      TravelOrigin at(int h, {int? end = 16 * 60}) => suggestOrigin(
        start: DateTime(2026, 9, 24, h),
        hasHome: true,
        hasSchool: true,
        departFromSchool: true,
        schoolEndMinutes: end,
      );
      expect(at(17), TravelOrigin.school);
      expect(at(10), TravelOrigin.home); // 授業中→ふだんは自宅から
      expect(at(21), TravelOrigin.home); // 夜は自宅から
      expect(at(17, end: null), TravelOrigin.home); // 授業のない日
    });

    test('片方しか登録していなければ、登録したほうから', () {
      expect(
        suggestOrigin(
          start: DateTime(2026, 9, 26, 10),
          hasHome: false,
          hasSchool: true,
          departFromSchool: true,
        ),
        TravelOrigin.school,
      );
    });
  });

  group('場所の文字', () {
    test('緯度・経度やマップの URL を読む', () {
      expect(parseLatLng('35.3389, 139.49'), const LatLng(35.3389, 139.49));
      expect(
        parseLatLng('https://www.google.com/maps/@35.3389,139.4900,15z'),
        const LatLng(35.3389, 139.49),
      );
      expect(
        parseLatLng('https://maps.google.com/?q=35.1,139.2'),
        const LatLng(35.1, 139.2),
      );
      expect(parseLatLng('藤沢駅'), isNull);
      expect(parseLatLng('100%'), isNull);
    });

    test('経路の URL：住所はそのまま、URL は緯度経度で', () {
      final a = directionsUri(
        from: fujisawaSt,
        destinationText: '横浜駅',
        mode: TravelMode.transit,
      );
      expect(a.queryParameters['destination'], '横浜駅');
      expect(a.queryParameters['travelmode'], 'transit');
      expect(a.queryParameters['origin'], '35.33870,139.48750');

      final b = directionsUri(
        from: fujisawaSt,
        destinationText: 'https://maps.app.goo.gl/xxxx',
        destination: yokohamaSt,
        mode: TravelMode.car,
      );
      expect(b.queryParameters['destination'], '35.46580,139.62230');
      expect(b.queryParameters['travelmode'], 'driving');
    });
  });

  group('位置の検索結果を読む', () {
    test('国土地理院', () {
      final r = parseGsi(
        '[{"geometry":{"coordinates":[139.49,35.3389],"type":"Point"},'
        '"type":"Feature","properties":{"addressCode":"","title":"神奈川県藤沢市"}}]',
      )!;
      expect(r.point, const LatLng(35.3389, 139.49));
      expect(r.label, '神奈川県藤沢市');
      expect(parseGsi('[]'), isNull);
    });

    test('Nominatim', () {
      final r = parseNominatim(
        '[{"lat":"35.4658","lon":"139.6223","display_name":"横浜駅"}]',
      )!;
      expect(r.point, const LatLng(35.4658, 139.6223));
      expect(parseNominatim('[]'), isNull);
    });
  });

  group('設定に保存する', () {
    test('自宅・学校の位置と移動の設定', () {
      final s = const AppSettings().copyWith(
        homeAddress: '藤沢市鵠沼',
        homePoint: fujisawaSt,
        schoolPoint: yokohamaSt,
        travelMode: TravelMode.car,
        travelBufferMinutes: 15,
        departFromSchool: false,
      );
      final back = AppSettings.fromMap(s.toMap());
      expect(back.homePoint, fujisawaSt);
      expect(back.schoolPoint, yokohamaSt);
      expect(back.homeAddress, '藤沢市鵠沼');
      expect(back.travelMode, TravelMode.car);
      expect(back.travelBufferMinutes, 15);
      expect(back.departFromSchool, isFalse);

      final cleared = back.copyWith(clearHome: true);
      expect(cleared.homePoint, isNull);
      expect(cleared.homeAddress, '');
      expect(cleared.schoolPoint, yokohamaSt);
    });

    test('緯度だけ・変な値は使わない', () {
      final s = AppSettings.fromMap(const {
        'homeLat': 35.3,
        'schoolLat': 999,
        'schoolLng': 139,
      });
      expect(s.homePoint, isNull);
      expect(s.schoolPoint, isNull);
    });
  });
}
