# マーカー追跡

QRコードやArUcoマーカーを見つけ、その場所に印を出すサンプルです。AR Foundationの`ARTrackedImageManager`に近い役目です。

印刷したマーカーを実空間に貼れば、そこが**アプリ側の既知の座標**になります。事前スキャンもアンカーの共有も要らないので、複数人で同じ場所に物を出したいときや、機械の特定の部位に情報を重ねたいときに向いています。

## 4つの種類

| 種類 | 読めるもの | 用途 |
| --- | --- | --- |
| QRコード | `get_marker_data()`で文字列 | URLやIDを埋め込む |
| マイクロQR | 同上 | 小さく貼りたいとき |
| ArUco | `marker_id`で番号 | 番号だけで足りるとき。検出が速い |
| AprilTag | 同上 | ロボティクスでよく使われる |

**端末によって対応が違います。** このサンプルは`is_qrcode_supported()`などで対応を調べ、**対応している種類だけ**を渡します。

```gdscript
var types := 0
if bool(_capability.call(&"is_qrcode_supported")):
	types |= MARKER_QR_CODE
...
_capability.call(&"start_built_in_tracking", types)
```

非対応の種類を混ぜると**まとめて失敗します**。全部立てて渡すのは避けてください。

## 見どころ

`start_built_in_tracking()`を1回呼べば、あとはruntimeがマーカーを探し続け、見つけたぶんだけ`XRServer`にトラッカーが増えます。**クエリのループも姿勢の追従も書きません。**

表示のしかたは[平面検出](../plane_detection/)や[空間アンカー](../spatial_anchor/)とまったく同じです。`XRAnchor3D`にトラッカー名を渡すだけです。

```gdscript
var anchor := XRAnchor3D.new()
anchor.tracker = tracker_name
_stage.origin.add_child(anchor)
```

`XRServer.TRACKER_ANCHOR`には平面やアンカーのトラッカーも混ざるので、`is OpenXRMarkerTracker`で選り分けます。

大きさ（`bounds_size`）と中身は追跡中に変わるので、毎フレーム引き直しています。

## マーカーを用意する

QRコードなら、任意のQR生成サービスで作ったものを印刷するだけです。読み取り距離は大きさに比例するので、**1辺10cm以上**にすると安定します。平らな面に貼り、しわや反射を避けてください。

ArUcoとAprilTagは辞書（dictionary）を合わせる必要があります。`project.godot`の次の設定で指定します。

- `xr/openxr/extensions/spatial_entity/marker_tracking/aruco_dict`
- `xr/openxr/extensions/spatial_entity/marker_tracking/april_tag_dict`

## 必要な設定

`project.godot`（設定済み）:

- `xr/openxr/extensions/spatial_entity/enabled`
- `.../marker_tracking/enable`

`marker_tracking/enable_builtin_for_types`は**あえて0のまま**にしています。ここに種類を書くとGodotが起動時に追跡を始めますが、端末の対応を調べずに固定の種類を要求することになるためです。このサンプルは実行時に調べて渡しています。

## 対応端末

`XR_EXT_spatial_marker_tracking`を公開するruntimeのみ。非対応端末では理由を表示します。

## 単体で動かす

`samples/marker_tracking/sample.tscn`をエディタで開いてF6。
