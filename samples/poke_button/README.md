# 押せるボタン

指先やコントローラーでボタンを押し込むサンプルです。3つのボタンが並び、押した回数が表示されます。

## 見どころ

- **押し込み量を1つの値にする**。板の沈み込み、色、押下判定をすべて`depth`から作ります。MRTK3の`StatefulInteractable`が持つ「選択の連続値（selectedness）」と同じ考え方で、ホバー時の色・押し込み中の見た目・離した瞬間の戻りが1箇所で決まります
- **押す位置と離す位置をずらす**（`PRESS_DEPTH` 11mm / `RELEASE_DEPTH` 5mm）。同じ閾値だと、指の震えで連打になります
- **ボタンのローカル座標へ移して判定する**。`to_local()`を通すと、面内かどうかと押し込み量が同時に出ます。物理エンジンもコリジョンも使っていません
- 指が見つからないときはコントローラーの位置で押せます。押したのがコントローラーなら`trigger_haptic_pulse()`で短く振動します

## 必要な設定

- 指で押すには`xr/openxr/extensions/hand_tracking=true`と、端末側のHand Tracking設定
- 振動は`openxr_action_map.tres`の`haptic`アクション（`/output/haptic`）

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/poke_button/sample.tscn`をエディタで開いてF6。
