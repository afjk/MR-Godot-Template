# 2D UIパネル

Godotの2D UI（`Control`）を3Dの板に貼り、ポインタで操作するサンプルです。ボタンとスライダーとチェックボックスが、隣の立方体を動かします。

## 見どころ

3D用のUIを作り直す必要はありません。やることは2つだけです。

1. **`SubViewport`の描画結果を板のテクスチャにする**

   ```gdscript
   material.albedo_texture = _ui.get_texture()
   ```

2. **当たった位置をピクセルへ直し、マウスイベントとして流し込む**

   ```gdscript
   var local := _panel.to_local(world_point)
   var uv := Vector2(local.x / PANEL_SIZE.x + 0.5, 0.5 - local.y / PANEL_SIZE.y)
   _ui.push_input(motion)   # position = uv * _ui.size
   ```

   これで既存の`Button`や`HSlider`がそのまま反応します。ホバーの見た目もGodotのテーマが面倒を見てくれます。

- `SubViewport`は`handle_input_locally = true`で、外のマウスとは切り離しています
- パネルの`Area3D`は専用の物理レイヤー（32）に置き、ランチャー（8）や他のサンプルのレイと混ざらないようにしています
- 板の解像度（512×320）と実寸（0.48m×0.30m）の比を揃えてあります。ずれると文字が伸びます

## 必要な設定

なし。

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/ui_panel_2d/sample.tscn`をエディタで開いてF6。
