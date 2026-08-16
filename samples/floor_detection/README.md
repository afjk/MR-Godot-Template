# 床面検知

床の高さを決めるサンプルです。半透明の板が床面、その上の立方体が「床に載っているか」の目印になります。

検出そのものを見たい場合は[平面検出](../plane_detection/)サンプルを開いてください。こちらは**検出結果から床を1つ選び、取れない端末では仮定に落とす**という、アプリ側の判断を扱います。

## 見どころ

| 段 | 方法 | 検知か | 端末 |
| --- | --- | --- | --- |
| 1 | coreの平面検出（`OpenXRPlaneTracker`）から`floor`ラベルの平面 | 検知 | 平面検出を公開するruntime |
| 2 | Metaの部屋スキャン結果（`OpenXRFbSceneManager`）の`FLOOR`ラベル | 検知（過去のスキャン結果） | Quest 3（Space Setup済み） |
| 3 | Local Floorの`y=0` | **仮定** | 全機種 |

**3段目は検知ではありません。** reference spaceがLocal Floorなので原点の足元が床「のはず」という前提です。PICO 4 UltraとVIVE Focus Visionでは、現状これが唯一の答えになります。

だからこそ**どの段で得たかを持ち続け、画面にも出します**。アプリ側は「精度が要る処理は仮定のときには実行しない」と書けます。

- ラベルを出さないruntimeのために、`floor`ラベルが無ければ**上向きの水平面のうち最も広いもの**を床とみなします
- 採用した平面は`XRAnchor3D`に貼り付け、毎フレーム高さを読み直します。平面は後から動くことがあります
- Meta経路では、**空の結果と「部屋を一度もスキャンしていない」を区別**します。`openxr_fb_scene_data_missing`を受けたら`request_scene_capture()`でSpace Setupへ誘導できます。ここを区別しないと、ユーザーは端末非対応だと思って原因にたどり着けません

## 必要な設定

- `project.godot`の`xr/openxr/extensions/spatial_entity/*`（このリポジトリでは設定済み）
- Meta経路は`xr/openxr/extensions/meta/scene_api=true`と、Quest 3端末側のSpace Setup

## 対応端末

| 端末 | 得られるもの |
| --- | --- |
| Quest 3 | 平面検出、またはMeta Sceneの部屋データ（Space Setup済みなら） |
| PICO 4 Ultra / VIVE Focus Vision | 現状はLocal Floorの仮定 |
| Android XR | 未検証。Trackablesの平面は[空間認識の検討メモ](../../docs/spatial_understanding_design.md)を参照 |

## 単体で動かす

`samples/floor_detection/sample.tscn`をエディタで開いてF6。
