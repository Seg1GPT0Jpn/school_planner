/**
 * つづり（school_planner）の Cloud Functions
 *
 * getTrainStatus:
 *   電車の運行情報（遅延情報）を取ってくる。
 *   ODPT（公共交通オープンデータセンター、https://developer.odpt.org/）のAPIキーを
 *   ここ（サーバー側）だけに置き、Flutter アプリ本体には一切含めない。
 *
 * getTravelEstimate:
 *   渋滞・遅延を考慮した、実際の移動時間を取ってくる（Google Maps Directions API）。
 *   Google Cloud の API キーを、ここ（サーバー側）だけに置く。
 *
 * どちらも Firebase の Blaze（従量課金）プランが必要。
 * アプリ側は、この関数が使えない・失敗したときは、距離から出した目安と
 * 「Google マップで経路を見る」（外部リンク・無料）に自動で切りかわる。
 * そのため、この関数をまだデプロイしていなくてもアプリは問題なく動く。
 *
 * APIキーの設定（初回だけ）：
 *   firebase functions:secrets:set ODPT_API_KEY
 *   → ODPT の開発者サイトで取得した consumerKey を入力する
 *   firebase functions:secrets:set GOOGLE_MAPS_API_KEY
 *   → Google Cloud Console で取得した、Directions API 用のキーを入力する
 *
 * デプロイ：
 *   firebase deploy --only functions
 */

const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const odptApiKey = defineSecret("ODPT_API_KEY");
const googleMapsApiKey = defineSecret("GOOGLE_MAPS_API_KEY");

const REGION = "asia-northeast1";

/**
 * 指定した路線ID（ODPT の odpt.Railway:...）の運行状況を返す。
 * 情報が無い路線は「平常運転」とみなす（呼び出し側で判断）。
 *
 * request.data: { lineIds: string[] }
 * 戻り値: { results: [{ railwayId, status, text, time }], fetchedAt }
 */
exports.getTrainStatus = onCall(
  {
    secrets: [odptApiKey],
    region: REGION,
    cors: true,
    // ログインしていない人には使わせない
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "ログインが必要です");
    }
    const lineIds = request.data && request.data.lineIds;
    if (!Array.isArray(lineIds) || lineIds.length === 0) {
      throw new HttpsError("invalid-argument", "lineIds が必要です");
    }
    // 念のため、変な値が大量に来ても困らないように制限
    const wanted = new Set(lineIds.filter((x) => typeof x === "string").slice(0, 30));

    const key = odptApiKey.value();
    const url =
      "https://api.odpt.org/api/v4/odpt:TrainInformation?acl:consumerKey=" +
      encodeURIComponent(key);

    let json;
    try {
      const res = await fetch(url, {signal: AbortSignal.timeout(10000)});
      if (!res.ok) {
        throw new Error("HTTP " + res.status);
      }
      json = await res.json();
    } catch (e) {
      logger.error("ODPT の取得に失敗しました", e);
      throw new HttpsError("unavailable", "運行情報を取得できませんでした");
    }

    if (!Array.isArray(json)) {
      throw new HttpsError("unavailable", "運行情報の形式が想定と違いました");
    }

    const results = [];
    for (const item of json) {
      const railwayId = item["odpt:railway"];
      if (!railwayId || !wanted.has(railwayId)) continue;

      results.push({
        railwayId,
        status: textOf(item["odpt:trainInformationStatus"]),
        text: textOf(item["odpt:trainInformationText"]),
        time: item["dc:date"] || null,
      });
    }

    return {
      results,
      fetchedAt: new Date().toISOString(),
    };
  },
);

/** ODPT のテキストは文字列のことも {ja: "...", en: "..."} のこともある */
function textOf(v) {
  if (typeof v === "string") return v;
  if (v && typeof v === "object") return v.ja || v.en || "";
  return "";
}

/**
 * 渋滞・電車の遅れを考慮した、実際の移動時間を Google Maps から取ってくる。
 *
 * request.data: {
 *   originLat, originLng, destLat, destLng,   // 緯度・経度
 *   mode: "transit" | "driving",
 *   arriveByMs: number | null,                // 「この時刻までに着きたい」（epoch ミリ秒）
 * }
 * 戻り値: { minutes, distanceMeters, fetchedAt }
 */
exports.getTravelEstimate = onCall(
  {
    secrets: [googleMapsApiKey],
    region: REGION,
    cors: true,
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "ログインが必要です");
    }
    const d = request.data || {};
    const originLat = Number(d.originLat);
    const originLng = Number(d.originLng);
    const destLat = Number(d.destLat);
    const destLng = Number(d.destLng);
    const mode = d.mode === "driving" ? "driving" : "transit";
    if (
      !Number.isFinite(originLat) || !Number.isFinite(originLng) ||
      !Number.isFinite(destLat) || !Number.isFinite(destLng)
    ) {
      throw new HttpsError("invalid-argument", "origin・destination が必要です");
    }

    const key = googleMapsApiKey.value();
    const params = new URLSearchParams({
      origin: `${originLat},${originLng}`,
      destination: `${destLat},${destLng}`,
      mode,
      key,
      language: "ja",
      region: "jp",
    });
    // 「この時刻までに着きたい」が分かっていれば、電車の乗り継ぎに反映される
    const arriveByMs = Number(d.arriveByMs);
    if (mode === "transit" && Number.isFinite(arriveByMs) && arriveByMs > 0) {
      params.set("arrival_time", String(Math.floor(arriveByMs / 1000)));
    }
    if (mode === "driving") {
      params.set("departure_time", "now");
    }

    const url = "https://maps.googleapis.com/maps/api/directions/json?" + params;

    let json;
    try {
      const res = await fetch(url, {signal: AbortSignal.timeout(10000)});
      if (!res.ok) throw new Error("HTTP " + res.status);
      json = await res.json();
    } catch (e) {
      logger.error("Directions API の取得に失敗しました", e);
      throw new HttpsError("unavailable", "移動時間を取得できませんでした");
    }

    if (json.status !== "OK" || !Array.isArray(json.routes) || json.routes.length === 0) {
      throw new HttpsError(
        "not-found",
        "経路が見つかりませんでした（" + (json.status || "unknown") + "）",
      );
    }

    const leg = json.routes[0].legs && json.routes[0].legs[0];
    if (!leg) {
      throw new HttpsError("not-found", "経路が見つかりませんでした");
    }

    // 渋滞込みの時間（driving_in_traffic）があればそれを、無ければ通常の所要時間を使う
    const durationSeconds =
      (leg.duration_in_traffic && leg.duration_in_traffic.value) ||
      (leg.duration && leg.duration.value) || 0;

    return {
      minutes: Math.max(1, Math.round(durationSeconds / 60)),
      distanceMeters: (leg.distance && leg.distance.value) || null,
      fetchedAt: new Date().toISOString(),
    };
  },
);
