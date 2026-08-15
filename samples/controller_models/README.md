# コントローラーモデル

runtimeが提供するコントローラーの3Dモデルを表示し、非対応なら球マーカーへ落とすサンプルです。

## 見どころ

モデルを供給するOpenXR extensionは2種類あり、**どちらを公開するかはruntimeによって違います**。

| extension | 実装元 | 確認済みの端末 |
| --- | --- | --- |
| `XR_EXT_render_model` | Godot 4.6 core（`OpenXRRenderModelManager`） | PICO 4 Ultra |
| `XR_FB_render_model` | OpenXR Vendors plugin（`OpenXRFbRenderModel`） | Meta Quest 3 |

そのため**両方を用意し、実際にモデルを返した方を毎フレーム採用**します。両方が返した場合はcore側を優先し、二重に描きません。どちらも返さない場合だけ、左右で色分けした球を出します。

- Meta経路は`ClassDB.instantiate()`でclass名から生成しています。OpenXR Vendors pluginが無い環境でも、このサンプルが読み込めるようにするためです
- モデルはgrip poseのコントローラーにぶら下げます。grip controllerはリグ側のノードなので、サンプルを閉じるときに`_exit_tree()`で自分で片付けます

## 必要な設定

- `project.godot`: `xr/openxr/extensions/render_model=true`、Meta経路は加えて`xr/openxr/extensions/meta/render_model=true`
- Quest: Export presetの`Meta XR Features > Render Model`（`Optional`以上）。これでAndroid manifestに`com.oculus.permission.RENDER_MODEL`が入ります

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR（非対応の場合は球マーカー）

## 単体で動かす

`samples/controller_models/sample.tscn`をエディタで開いてF6。
