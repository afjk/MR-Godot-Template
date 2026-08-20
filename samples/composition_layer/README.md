# Composition layer

文字を**runtimeに直接合成させて**、通常の3D描画より鮮明に出すサンプルです。

左が composition layer、右が同じ内容の通常描画です。**近づいて見比べてください。**

## なぜ鮮明になるのか

通常の3D描画では、UIはまず目のレンダーターゲットへ描かれ、そのあとレンズの歪み補正で引き伸ばされます。**2回サンプリングされるので、細い線や小さい文字がにじみます。**

composition layerは、その板だけをruntimeへ渡します。runtimeは最終合成のときに1回だけサンプリングするので、元の解像度がそのまま出ます。文字の読みやすさが目に見えて変わります。

[2D UIパネル](../ui_panel_2d/)は同じ`SubViewport`を通常の板に貼っています。仕組みの違いはそこだけです。

## 書き方

```gdscript
var layer := OpenXRCompositionLayerQuad.new()
layer.quad_size = PANEL_SIZE
layer.alpha_blend = true          # パススルーの上に出すなら必須
var viewport := SubViewport.new()
layer.add_child(viewport)
layer.layer_viewport = viewport
```

`SubViewport`は**composition layerの子にしてから**`layer_viewport`へ渡します。

`is_natively_supported()`が偽なら、runtimeがこの種類のレイヤーに対応していないので、Godotが通常描画に落とします。**アプリ側の場合分けは要りません**が、鮮明さの差も出なくなるので、このサンプルは状態を表示しています。

## 代償

**3Dシーンの中に入り込めません。** runtimeが最後に合成するので、仮想物体との前後関係は`sort_order`と`enable_hole_punch`でしか扱えません。

- UIパネル、動画プレイヤー、テキストの多い表示 → 向く
- ワールドに溶け込ませたい表示、他の物体に隠れてほしい表示 → 向かない

## 対応端末

全機種。非対応runtimeでは通常描画に落ちます。

## 単体で動かす

`samples/composition_layer/sample.tscn`をエディタで開いてF6。
