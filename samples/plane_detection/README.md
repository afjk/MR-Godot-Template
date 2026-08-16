# 平面検出

runtimeが検出した平面（床・壁・天井・机）を、その場に半透明で重ねて表示します。AR Foundationの`ARPlaneManager`に当たるサンプルです。

## 見どころ

Godot 4.6 coreの**Spatial Entities**（`XR_EXT_spatial_plane_tracking`）を使います。ベンダー固有のAPIではありません。

- 平面は`XRServer`に**anchor種別のトラッカー**として現れます。アプリ側は増減を購読するだけです

  ```gdscript
  XRServer.tracker_added.connect(_on_tracker_added)
  for tracker_name in XRServer.get_trackers(XRServer.TRACKER_ANCHOR):
      var tracker := XRServer.get_tracker(tracker_name) as OpenXRPlaneTracker
  ```

- 位置合わせは`XRAnchor3D`に`tracker`名を渡すだけで済みます。姿勢の追従を自分で書く必要はありません
- 形も`OpenXRPlaneTracker`が持っています。`get_mesh()`（表示用）、`get_shape()`（当たり判定用）、`get_mesh_offset()`（両者を置く位置）
- 平面は後から形が変わります。`mesh_changed`シグナルで貼り直します
- 種類は`plane_label`（`floor` / `wall` / `ceiling` / `table`）で分けます。**ラベルを出さないruntimeもある**ので、そのときは`plane_alignment`（上向き・下向き・垂直）で大まかに分類します

`XRAnchor3D`は`XROrigin3D`の下に置きます。トラッカーの姿勢を自分のローカル変換にするノードなので、原点の外に置くとリグが動いたときにずれます。

## この端末で何も出ないとき

- **「平面検出を公開していません」**: runtimeが`XR_EXT_spatial_plane_tracking`に対応していません。Quest 3で部屋データを使いたい場合は、Meta固有の経路（`floor_detection`サンプルの2段目）になります
- **「まだ平面がありません」**: 対応はしているが、まだデータが無い状態です。端末側で部屋のスキャン（Space Setupなど）が済んでいるか確認してください

## 必要な設定

- `project.godot`（このリポジトリでは設定済み）
  - `xr/openxr/extensions/spatial_entity/enabled=true`
  - `xr/openxr/extensions/spatial_entity/enable_plane_tracking=true`
  - `xr/openxr/extensions/spatial_entity/enable_builtin_plane_detection=true`
- 端末によっては権限がExport presetに要ります（[docs/build.md](../../docs/build.md)）

## 対応端末

`XR_EXT_spatial_plane_tracking`を公開するruntimeのみ。非対応の端末では、その旨を表示して何も置きません。

## 単体で動かす

`samples/plane_detection/sample.tscn`をエディタで開いてF6。
