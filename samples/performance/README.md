# 性能の見方

foveationとMSAAを切り替えて、効き方を実機で確かめるサンプルです。

- 右手のpinch: foveationの強さを 切／低／中／高 で回す
- 左手のpinch: MSAAを 切／2x／4x で回す

## 何を触っているか

MRの負荷は、ほとんどが**解像度と塗り面積**で決まります。この2つがいちばん効きます。

**foveation。** 視界の周辺を粗く描きます。人間の視野は中心以外の解像度が低いので、**効果に対して劣化が見えにくい**のが利点です。`foveation_dynamic`にすると、負荷に応じて強弱が自動でつきます。

**MSAA。** 斜めの線のギザギザを消します。XRでは画素が大きく見えるので2xでも効果が大きく、そのぶん重くなります。

```gdscript
_stage.xr_interface.foveation_level = level       # 0=切 〜 3=高
_stage.xr_interface.foveation_dynamic = level > 0
get_viewport().msaa_3d = Viewport.MSAA_2X
```

## 数字を動かすために

設定を変えても、負荷が軽ければFPSは変わりません。差が見えるように**立方体を240個**出しています。数を変えたいときは`CUBE_COUNT`です。

表示している値の意味はこうです。

| 表示 | 意味 |
| --- | --- |
| FPS | 実測のフレームレート |
| 表示レート | runtimeが出している表示レート。起動時に最良のものを選んでいる |
| 描画解像度 | 片目ぶんのレンダーターゲット。foveationでは変わらない |

**描画解像度がfoveationで変わらない**のは、foveationが解像度ではなく「どこを粗く塗るか」を変えるものだからです。

## 既定値

このリポジトリの既定は`project.godot`にあります。

- `xr/openxr/foveation_level=3`（高）
- `xr/openxr/foveation_dynamic=true`
- MSAA 2x

Quest 3・PICO 4 Ultra・VIVE Focus VisionのようなモバイルGPUでは、この組み合わせが出発点として妥当です。**ここから下げるのではなく、まずこれで測ってください。**

## 対応端末

全機種。ベンダー固有の計測値（`OpenXRVendorPerformanceMetrics`）は扱っていません。より細かく測りたい場合はそちらを見てください。

## 単体で動かす

`samples/performance/sample.tscn`をエディタで開いてF6。
