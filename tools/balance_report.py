"""Render checked-in study scripts' JSON measurements into a local review document."""
import csv
import json
import statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs/validation/high-floor"
DEST = ROOT / "docs/HIGH_FLOOR_BALANCE.md"
NAMES = ["SIEGE", "VECTOR", "HALO"]
WEAPONS = ["Scatter", "Shock", "Lance"]


def read(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def table(headers, rows):
    return "\n".join([
        "| " + " | ".join(headers) + " |",
        "| " + " | ".join(["---"] * len(headers)) + " |",
        *["| " + " | ".join(map(str, row)) + " |" for row in rows],
    ])


def csv_file(name, rows):
    if not rows:
        return
    with (DATA / name).open("w", newline="", encoding="utf-8-sig") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def span(values):
    return f"{min(values):.2f}–{max(values):.2f}"


def main():
    numbers = read(DATA / "tables.json")
    rooms = read(DATA / "rooms.json")
    bosses = [row for path in sorted(DATA.glob("boss-*.json")) for row in read(path)]
    normals = [row for path in sorted(DATA.glob("normal-*.json")) for row in read(path)]
    lines = [
        "# 高層雑魚・ボスの難易度調整 — 2026-09-19",
        "",
        "**2026-09-20追補:** 盾の旋回とボスHP・サイズ・被弾範囲は [最新の調整記録](BOSS_SIZE_TUNING.md) を参照。以下のボス戦実測は9月19日時点の記録であり、現在のコードで再実行すると結果は変わる。",
        "",
        "## 実装と評価の範囲",
        "",
        "通常雑魚は30階まで維持。31階以降は旧HPに `(1 + (floor - 30) / 20)^3` を掛ける。狙撃型だけ倍率の平方根を使い、固定基準ダメージの2発分を上限とする。盾の本体HPは1。召喚雑魚も同じ計算を使う。",
        "",
        "敵数・構成・移動速度・弾速・攻撃間隔・突破条件・カード・実際の射撃処理は変更していない。ボス本体は全階層で調整。ボスHPは実効通常DPSと基準サブDPSの合計の12秒分、SIEGE/HALOは係数1.0、VECTORは0.90。SIEGEは6砲台へ均等配分する。",
        "",
        "基準サブDPSはScatter 6発命中、Shock/Lanceは1対象命中で計算し、最大値を採用する。ダメージ・再使用速度・物理更新周期を反映する。HPは生成時に確定し、持ち替えや戦闘中の操作では変わらない。",
        "",
        "50階前後が一般プレーヤーの難関、100階付近が極めて厳しいことは試遊目標。逃走突破を維持しているため到達不能は保証しない。以下のbot測定は人の生存率・到達階の推定ではない。",
        "",
        "## 雑魚HPと想定通常火力（計算値）",
        "",
        "104階の添付値を基準に `power = 1 + 13.2*(floor-1)/103`、`rate = 1 + 8*(floor-1)/103` と置いた比較モデル。取得履歴の再現や平均的なプレーヤーの実測値ではない。HPは内部値であり、ダメージ表示は10倍。60Hz時の発射間隔の切り上げと1更新1発上限を反映する。",
        "",
        table(["階数基準", "追跡HP", "狙撃HP", "FLANKER / INTERCEPTOR HP", "盾HP", "弾ダメージ", "連射倍率", "実効通常DPS"], [
            [r["depth"], f'{r["hp"]["0"]:.2f}', f'{r["hp"]["1"]:.2f}', f'{r["hp"]["4"]:.2f}', 1, f'{r["power"]:.2f}', f'{r["rate"]:.2f}', f'{r["primary_dps"]:.1f}'] for r in numbers
        ]),
        "",
        "5の倍数は実際にはボス階。雑魚HP欄はその階数の計算値であり、通常フロアが生成されるという意味ではない。連射が更新周期の境界を越えると実効DPSは段階的に上がるため、各階の体感難度が厳密に単調増加するわけではない。",
        "",
        "## 部屋ごとの出現数（生成実測）",
        "",
        "seed 7 / 93 / 19045。開始部屋は0体。以下の最小・中央値・最大は開始部屋を除いた全戦闘部屋。全seed・全室の種別内訳は [rooms.csv](validation/high-floor/rooms.csv)。",
        "",
    ]
    room_rows = []
    flat_rooms = []
    for r in rooms:
        flat_rooms.append({"reference_depth": r["reference_depth"], "actual_depth": r["actual_depth"], "seed": r["seed"], "room": r["room"], **{name: r["counts"][kind] for kind, name in [("0", "chaser"), ("1", "sniper"), ("2", "shield"), ("4", "flanker"), ("5", "interceptor")]}})
    for depth in [r["depth"] for r in numbers]:
        selected = [r for r in rooms if r["reference_depth"] == depth and r["room"] != 0]
        totals = [sum(r["counts"].values()) for r in selected]
        room_rows.append([depth, selected[0]["actual_depth"], len(selected), min(totals), statistics.median(totals), max(totals)])
    lines += [table(["階数基準", "実生成階", "戦闘部屋数", "最小", "中央値", "最大"], room_rows), "", "85体の部屋は追跡56・狙撃13・盾8・FLANKER 6・INTERCEPTOR 2。敵数の式と配置可能地点による減少は従来どおり。", "", "## サブ威力（計算値）", "", "必要命中数は追跡型1体に対する値。Scatterは弾1発単位で、複数発命中なら必要な発射回数は減る。範囲攻撃の総効果は単体DPSへ合算しない。", ""]
    sub_rows = []
    for r in numbers:
        for s in r["sub"]:
            sub_rows.append([r["depth"], WEAPONS[s["weapon"]], f'{s["damage_per_hit"]:.2f}', s["hits_to_chaser"], f'{s["cooldown_base"]:.2f}', f'{s["cooldown_max_recharge"]:.3f}'])
    lines += [table(["階", "武器", "1命中ダメージ", "追跡型への必要命中数", "基礎再使用秒", "最大再使用強化時の設定秒"], sub_rows), "", "再使用の設定秒は物理更新周期へ切り上げられる。初弾をすぐ撃てる効果は継続DPSと別で、下記の戦闘測定には含まれる。", "", "## ボス戦（実測）", "", "seed 19045、60Hz、階数−1枚の合法カードを固定方針で取得する。実際の3択抽選の出現確率は再現しない。標準はHeavy/Overclock/Hunter/Quickstep、通常火力重視はHeavy/Overclock/Heavy/Overclock/Hunter/Quickstep、サブ重視はExpansion/Capacitor/Heavy/Hunter/Quickstepを循環する。上限到達時は実装された代替カード列を使う。", "", "測定開始位置はボス部屋入口。通常弾と選択サブを併用する。保護付きは狙った距離へ移動して攻撃し、通常ダメージありは簡易旋回・回避を加える。死亡はその場で失敗として記録し、リトライ後の撃破を成功に数えない。35秒で未撃破なら打ち切る。", ""]
    boss_table = []
    for depth in sorted({r["depth"] for r in bosses}):
        for boss in range(3):
            selected = [r for r in bosses if r["depth"] == depth and r["boss"] == boss and r["protected"]]
            clears = [r["seconds"] for r in selected if r["outcome"] == "clear"]
            normal = [r for r in bosses if r["depth"] == depth and r["boss"] == boss and not r["protected"]]
            standard = [r["seconds"] for r in selected if r["build"] == "standard" and r["outcome"] == "clear"]
            boss_table.append([depth, NAMES[boss], span([r["hp"] for r in selected]), span(standard) if standard else "未撃破", span(clears) if clears else "未撃破", f'{len(clears)}/{len(selected)}', "/".join(str(sum(r["outcome"] == status for r in normal)) for status in ["clear","death","timeout"])])
    lines += [table(["階", "ボス", "総HPの範囲", "標準構成の保護付き秒", "全構成の保護付き秒", "保護付き撃破", "通常試行 成功/死亡/打切"], boss_table), "", "全条件の能力値・HP・残HP・撃破時間・最大敵弾・最大召喚数は [boss.csv](validation/high-floor/boss.csv)。保護付きの結果は攻撃機会の測定であり、回避込み30秒以内という人の試遊評価の代わりにはならない。", ""]
    if bosses:
        successful = [r["seconds"] for r in bosses if r["protected"] and r["outcome"] == "clear"]
        lines += [f"保護付きの撃破時間全体は {span(successful)} 秒。10秒未満 {sum(t<10 for t in successful)} 件、30秒超 {sum(t>30 for t in successful)} 件。VECTORの最大召喚雑魚数は {max(r['max_mobs'] for r in bosses if r['boss']==1)} 体で、既存上限24体を維持。", ""]
    lines += ["## 通常階の戦闘試行", "", "全フロア攻略ではなく、部屋1へ入った時点からの最大30秒試行。保護付きでも制限時間は有効。30秒内に部屋1の敵を全滅できた場合を部屋クリアとする。各階で標準・通常火力重視・サブ重視×サブ3種を測る。地形や狙い方の影響があり、低層でも部屋全滅しないケースがある。", ""]
    normal_table = []
    for depth in sorted({r["depth"] for r in normals}):
        protected = [r for r in normals if r["depth"] == depth and r["protected"]]
        unprotected = [r for r in normals if r["depth"] == depth and not r["protected"]]
        normal_table.append([depth, span([r["kills"] for r in protected]), sum(r["outcome"] == "room_clear" for r in protected), sum(r["outcome"] == "death" for r in unprotected), max(r["max_bullets"] for r in protected)])
    lines += [table(["階", "保護付き撃破数", "保護付き部屋クリア/9", "通常試行死亡/9", "最大弾数（味方含む）"], normal_table), "", "詳細は [normal.csv](validation/high-floor/normal.csv)。生存率や最終到達階はこの簡易botから推定しない。", "", "## 実描画・性能", ""]
    if (DATA / "render.json").exists():
        render = read(DATA / "render.json")
        lines += [f"{render['engine']} / {render['cpu']} / {render['renderer']}、25度3D、各600フレーム。保護付き・通常階のみタイマーを止めた負荷測定。旧版との比較ではなく、同端末での観測値。", "", table(["階", "CPU更新p95 ms", "フレーム間隔p95 ms", "フレーム間隔最大 ms", "最大弾数", "最大雑魚数"], [[r["depth"], f'{r["cpu_ms"]["p95"]:.3f}', f'{r["frame_ms"]["p95"]:.3f}', f'{r["frame_ms"]["max"]:.3f}', r["max_bullets"], r["max_mobs"]] for r in render["rows"]]), "", "最大フレーム間隔には一時的な伸びが残る。全フレームの60fps維持や旧版に対する性能改善は主張しない。3枚の実画面を目視確認し、HUD・敵・攻撃表示の崩れは見られなかった。", "", "実画面: [49階](validation/high-floor/render-49.png) / [99階](validation/high-floor/render-99.png) / [VECTOR100](validation/high-floor/render-100.png)。", ""]
    else:
        lines += ["実描画測定は未完了。", ""]
    lines += ["## 回帰検証と再現", "", "変更前commit `26808167aeefc865780d09b872fe821caf185d4e` の生成処理を使い、1〜30階の全通常階×3seed、72件のSHA-256を記録。現在の地形・敵の全データ・制限時間・乱数状態が全件一致。", "", "通常射撃のみの旧ボステストはサブ併用を想定していないため、フォールバックとして45秒以内を検証する。別の併用テストで代表構成の10〜30秒を検証し、全条件の測定結果も保存する。", ""]
    test_file = ROOT / "docs/validation/tests.json"
    if test_file.exists():
        tests = read(test_file)
        lines += [f"既存を含むテスト: {sum(bool(r['Passed']) for r in tests)}/{len(tests)} PASS。", ""]
    lines += ["再現（プロジェクト直下）:", "", "```powershell", "./tools/test.ps1", "& C:/Users/ysyki/Godot/Godot_console.exe --headless --path . --disable-crash-handler --log-file docs/validation/high-floor-tables.log --script res://tools/balance_study.gd -- --mode=tables", "& C:/Users/ysyki/Godot/Godot_console.exe --headless --path . --disable-crash-handler --log-file docs/validation/high-floor-boss.log --script res://tools/balance_study.gd -- --mode=boss", "& C:/Users/ysyki/Godot/Godot_console.exe --headless --path . --disable-crash-handler --log-file docs/validation/high-floor-normal.log --script res://tools/balance_study.gd -- --mode=normal --frames=1800", "& C:/Users/ysyki/Godot/Godot_console.exe --path . --disable-crash-handler --log-file docs/validation/high-floor-render.log --script res://tools/balance_render.gd", "python tools/balance_report.py", "```", "", "実装と自動検証の完了は、人の試遊による最終バランス承認と区別する。公開・配布版の書き出しは今回実施しない。", ""]
    DEST.write_text("\n".join(lines), encoding="utf-8")
    csv_file("rooms.csv", flat_rooms)
    csv_file("boss.csv", bosses)
    csv_file("normal.csv", normals)
    print(DEST)


if __name__ == "__main__":
    main()
