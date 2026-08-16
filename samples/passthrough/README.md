# パススルー

MRを開始する条件と、environment blend modeの違いを見るサンプルです。

正面のキューブを回しながら、5秒ごとに`ALPHA_BLEND`と`OPAQUE`を切り替えます。`ALPHA_BLEND`では背景が実世界に、`OPAQUE`では黒い背景になります。MRを開始できない環境では、理由を表示してデスクトップ表示のままになります。

## 見どころ

- MRの開始判定そのものは[`shared/mr_stage.gd`](../../shared/mr_stage.gd)にあります。全サンプルが必要とするため、共通側に置いています
- 開始前に`get_supported_environment_blend_modes()`で対応を確認し、対応していなければ開始しません。「対応しているつもりで真っ黒」を避けるためです
- 切り替えは`XRInterface.environment_blend_mode`の代入だけです。あわせて`Viewport.transparent_bg`と背景色も切り替えます

## 必要な設定

- `project.godot`: `xr/openxr/environment_blend_mode=2`
- Quest: Export presetの`Meta XR Features > Passthrough`を`Required`
- PICO / VIVE: 各presetのpassthrough設定（[docs/build.md](../../docs/build.md)）

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/passthrough/sample.tscn`をエディタで開いてF6を押すと、このサンプルだけが起動します。XRリグは`SampleBootstrap`が実行時に挿します。
