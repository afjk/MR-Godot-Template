# ハンドメニュー

手のひらを自分へ向けるとメニューが出るサンプルです。MRTKのSolver（HandConstraint）に当たります。

## 見どころ

**1. 手のひらの向きを関節から自分で作る。** 手首・人差し指の付け根・小指の付け根が作る三角形の法線を使います。

```gdscript
var normal := (index - wrist).cross(pinky - wrist)
```

関節の並びは左右で鏡になるので、片方だけ符号を反転します（`PALM_SIGN`）。**実機で手の甲を向けたときに出てしまう場合は、この符号を入れ替えてください。**

**2. 出す条件と消す条件をずらす。** 出すのは内積0.72以上、消すのは0.45未満、さらに0.35秒待ってから消します。同じ閾値で即座に消すと、手がわずかに揺れるだけでメニューが点滅します。

**3. 目標へ少しずつ近づける。**

```gdscript
var weight := 1.0 - exp(-FOLLOW_SPEED * delta)
_menu.global_transform = _menu.global_transform.interpolate_with(target, weight)
```

`delta`を指数に入れることで、フレームレートが変わっても追従の速さが変わりません。手の姿勢をそのままコピーすると細かい震えがそのまま出るので、目標はカメラの方を向く姿勢にして、そこへ滑らかに寄せます。

項目の切り替えはpinchです。押しっぱなしで回り続けないよう、`MRStage.is_pinch_just_started()`で始まった瞬間だけ拾います。

## 必要な設定

- `xr/openxr/extensions/hand_tracking=true`と、端末側のHand Tracking設定

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

光学式のHand Trackingが動いていない場合は、メニューを出さずにその旨を表示します。コントローラーを置いて手をかざしてください。

## 単体で動かす

`samples/hand_menu/sample.tscn`をエディタで開いてF6。
