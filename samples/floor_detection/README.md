# 床面検知

床の高さを決めるサンプルです。半透明の板が床面、その上の立方体が「床に載っているか」の目印になります。

## 見どころ

MRで最初に要るのが床の高さですが、取り方は端末で違います。**上から順に試して、どの段で得たかを持ち続ける**のがこのサンプルの主題です。

| 段 | 方法 | 使える端末 |
| --- | --- | --- |
| 1 | 平面API。Metaのscene entityから`FLOOR`ラベルの高さを読む | Quest 3（Space Setup済み） |
| 2 | 手で合わせる。実際の床に指先を置いてpinch | Hand Trackingがある端末 |
| 3 | Local Floor。reference spaceがLocal Floorなので`XROrigin3D`の`y=0`が床 | 全機種 |

3段目は**検知ではなく仮定**です。PICO 4 UltraとVIVE Focus Visionでは、現状これが唯一の答えになります。だからこそ出所（`_source`）を持ち、画面にも出します。精度が要る処理は出所を見て分岐できます。

```gdscript
var labels: PackedStringArray = entity.call(&"get_semantic_labels")
if FLOOR_LABEL not in labels:
    continue
_height = anchor.global_position.y
```

- **空の結果とセットアップ未完了を区別します**。`openxr_fb_scene_data_missing`を受けたら`request_scene_capture()`でSpace Setupへ誘導できます。「部屋をスキャンしていないだけ」なのに「非対応」と表示すると、ユーザーは原因にたどり着けません
- `OpenXRFbSceneManager`は`ClassDB.instantiate()`でclass名から生成しています。OpenXR Vendors pluginが無い環境でも、このサンプルは読み込めます
- 平面APIの問い合わせは0.5秒ごとです。毎フレーム引く必要はありません

## 必要な設定

- `project.godot`: `xr/openxr/extensions/meta/scene_api=true`、`xr/openxr/extensions/meta/anchor_api=true`（このリポジトリでは設定済み）
- Quest 3の端末側で**Space Setup（部屋のスキャン）を実行しておく**こと。未実施ならアプリから誘導します
- 手で合わせるには`xr/openxr/extensions/hand_tracking=true`

## 対応端末

| 端末 | 得られるもの |
| --- | --- |
| Quest 3 | 平面API（Space Setup済みなら） |
| PICO 4 Ultra / VIVE Focus Vision | Local Floorの仮定、または手で合わせた高さ |
| Android XR | 未検証。Trackablesの平面は[空間認識の検討メモ](../../docs/spatial_understanding_design.md)を参照 |

## 単体で動かす

`samples/floor_detection/sample.tscn`をエディタで開いてF6。
