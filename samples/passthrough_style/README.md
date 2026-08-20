# パススルーの色調整

実世界の見え方そのものを、runtime側で加工するサンプルです。pinchで4つの見え方を切り替えます。

| 見え方 | 中身 |
| --- | --- |
| そのまま | 加工なし |
| 明るさ・彩度 | brightness / contrast / saturation の3値 |
| モノクロ | 輝度を`Curve`で階調に置き換える |
| カラーマップ | 輝度を`Gradient`の色に置き換える（擬似カラー） |

## 見どころ

仮想物体に色をかけるのではなく、**パススルー映像そのものを加工します**。合成はruntimeが行うので、**アプリ側の描画負荷はゼロ**です。ポストプロセスで同じ見た目を作ろうとすると、そもそもパススルー映像がアプリから見えないので不可能です。

```gdscript
_extension.call(&"set_brightness_contrast_saturation", 10.0, 1.4, 1.6)
_extension.call(&"set_mono_map", curve)       # 輝度 → 階調
_extension.call(&"set_color_map", gradient)   # 輝度 → 色
```

引数の中立値は、明るさ`0`（範囲-100〜100）、コントラストと彩度が`1.0`（0より大）です。

## 実装で外せない点

**同時に効くフィルタは1つだけです。** 別のフィルタを設定すると前のものは外れます。上の3つはどれも「設定すると同時にそのフィルタへ切り替わる」動きをします。

**戻すときだけ専用の呼び出しが要ります。**

```gdscript
_extension.call(&"set_passthrough_filter", FILTER_DISABLED)
```

**サンプルを抜けるときに戻す。** 加工したままにすると、ランチャーへ戻ったあとも色が変わったままになります。`_exit_tree`で無効化しています。

## 使いどころ

- 暗い部屋でコントラストを上げて見やすくする
- 世界観に合わせて色を寄せる（夜のシーンで青く沈める等）
- 擬似カラーで、明るさの分布を見せる

`set_edge_color()`で輪郭線を描く、`set_texture_opacity_factor()`でパススルーを薄くする、といった調整もあります。

## 必要な設定

- `project.godot`: `xr/openxr/extensions/meta/passthrough=true`（設定済み）
- OpenXR Vendors plugin

## 対応端末

Quest 3のみ。非対応端末では理由を表示します。モノクロパススルーの端末では色の変化は出ません（`has_color_passthrough_capability()`で分かります）。

## 単体で動かす

`samples/passthrough_style/sample.tscn`をエディタで開いてF6。
