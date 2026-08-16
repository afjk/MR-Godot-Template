# リアルタイム平面推定

見ている先の面を、その場の深度から毎回作り直すサンプルです。

[平面検出](../plane_detection/)との違いがこのサンプルの主題です。

| | 平面検出 | リアルタイム平面推定 |
| --- | --- | --- |
| データ源 | **事前スキャン済み**の部屋データ | runtimeが毎フレーム作る**深度マップ** |
| 机を動かしたら | 平面は動かない | 追従する |
| 事前準備 | Space Setupが必要 | 不要 |
| 精度 | 高い（人が確認した面） | 低い（ノイズあり） |
| 対応 | `XR_EXT_spatial_plane_tracking` | Quest 3の`XR_META_environment_depth` |

## 見どころ

Vendorsプラグインのドキュメントが「独自のrealtime plane trackingの実装に使える」と書いているCPU側の深度取得を使います。

```gdscript
_extension.call(&"get_environment_depth_map_async", _on_depth_map)
# コールバックには左右ぶんの辞書が届く
#   image: Image、depth_projection_view / depth_inverse_projection_view: Projection
```

手順は3つです。

1. 深度マップをCPUへ落とす
2. 画面中央付近の点を、逆行列でワールド座標へ戻す
3. 戻した点群から重心と法線を出す（外積の平均。固有値分解までは要りません）

**引く間隔が重要です。** 深度マップは毎フレーム更新されるわけではなく（表示レートにもよりますが2〜4フレームに1回程度）、GPUからCPUへの転送も安価ではありません。ドキュメントの助言どおり1秒に1回程度にしています。描画に使うなら、この方法ではなくシェーダーからグローバルuniform越しに読むほうが適切です。

## 実機で確認したい点

深度値の扱いには**確認できていない前提**があります。

```gdscript
# 深度値は0〜1で入っている前提で、GodotのProjectionが使う-1〜1へ広げる
var ndc := Vector3(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0, raw_depth * 2.0 - 1.0)
```

この前提が違うと距離がおかしくなります。画面に**推定距離とサンプル数**を出しているので、実際の距離と合っているかを見てください。合わない場合、`_unproject()`のこの1行が疑わしい箇所です（0〜1のまま渡す、逆方向にする、などの可能性）。

## 必要な設定

- `project.godot`: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）
- OpenXR Vendors plugin

## 対応端末

Quest 3のみ。非対応端末では理由を表示します。

## 単体で動かす

`samples/realtime_planes/sample.tscn`をエディタで開いてF6。
