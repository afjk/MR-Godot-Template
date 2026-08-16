# Hand Tracking

`XRHandTracker`が返す左右26関節を、球で表示するサンプルです。

関節ごとに取得できる半径で球の大きさを変え、位置が有効な関節だけを表示します。左手は青、右手は赤です。

## 見どころ

- **光学式の手と、コントローラー由来の推定手を見分けています**。`hand_tracking_source`が`CONTROLLER`または`NOT_TRACKED`のときは、関節が来ていても表示しません。コントローラーを握っているのに手の球が重なって出るのを避けるためです（判定は[`shared/mr_stage.gd`](../../shared/mr_stage.gd)の`is_hand_tracking_active()`）
- 関節の姿勢は`XROrigin3D`基準で返るため、`origin.global_transform`を通してから配置します
- `get_hand_joint_flags()`の`POSITION_VALID`を見て、無効な関節は隠します

## 必要な設定

- `project.godot`: `xr/openxr/extensions/hand_tracking=true`
- Quest: Export presetの`Meta XR Features > Hand Tracking`
- PICO / VIVE: 各presetのhand tracking設定（[docs/build.md](../../docs/build.md)）

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/hand_tracking/sample.tscn`をエディタで開いてF6。
