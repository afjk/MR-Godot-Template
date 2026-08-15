# 掴んで動かす

pinch（手）またはgrip（コントローラー）でオブジェクトを掴み、手について来させるサンプルです。

## 見どころ

- **掴んだ瞬間の相対姿勢を1つの`Transform3D`として保存**し、以降は毎フレームそれを手の姿勢へ掛け直すだけです。

  ```gdscript
  _offsets[hand] = grab_transform.affine_inverse() * cube.global_transform
  # 以降
  cube.global_transform = grab_transform * _offsets[hand]
  ```

  位置と回転を別々に扱うより短く、掴んだときの持ち方がずれません
- **物理を使っていません**。掴める判定は手の代表点からの距離だけです。オブジェクトが数個なら、`Area3D`を置くより速く、フレーム同期のずれも出ません
- 掴む基準は、手なら手のひら（`HAND_JOINT_PALM`）、コントローラーならgrip pose。どちらも姿勢（回転を含む）が取れるので、同じコードで扱えます
- 両手で別々のオブジェクトを掴めます。同じものを2つの手で掴むこと（両手操作）は`two_hand_manipulation`サンプルの主題です

## 必要な設定

- 手で掴むには`xr/openxr/extensions/hand_tracking=true`（pinchの判定と閾値は`shared/mr_stage.gd`）
- コントローラーは`openxr_action_map.tres`の`grab`アクション（`squeeze/value`）

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/grab_object/sample.tscn`をエディタで開いてF6。
