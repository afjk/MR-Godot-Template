# Android XRのリアルタイム平面検出

OSが逐次見つけた平面を、そのまま受け取るサンプルです。**AR Foundationの`ARPlaneManager`と同じ挙動になる唯一の経路**です。

> **実機が無いため未検証です。** コードはOpenXR Vendors同梱のサンプルとプラグインのドキュメントに合わせてあります。

## Quest 3との違い

| | [平面検出](../plane_detection/)（Quest 3） | このサンプル（Android XR） |
| --- | --- | --- |
| データ源 | Space Setupの**事前スキャン** | OSが見た端から作る |
| 事前準備 | 必要 | **不要** |
| 机を動かしたら | 平面は動かない | 追従する |
| 平面が増えるか | 増えない | 見回すと増える |
| 拡張 | `XR_EXT_spatial_plane_tracking` | `XR_ANDROID_trackables` |

Quest 3のOSはリアルタイム平面検出を提供しません。これはAR Foundationを使っても同じです（[調査メモ](../../docs/realtime_spatial_investigation.md)）。Quest 3で同じことをしたければ、深度から自作する[リアルタイム複数平面検出](../realtime_plane_clusters/)になります。

## 見どころ

取り方は`plane_detection`とほぼ同じで、`XRServer`のトラッカーを購読して`XRAnchor3D`に渡すだけです。違いは2つあります。

**形が動き続ける。** `updated`シグナルが飛んでくるので、そのたびに`get_mesh()`と`get_shape()`を引き直します。当たり判定も一緒に作り直せます。

**平面が別の平面に吸収される。** 小さい平面が、あとで見つかった大きい平面の一部だと分かることがあります。そのとき`get_subsumed_by_plane()`が吸収した側を返すので、**吸収された側は表示しません**。これをやらないと同じ面に板が二重に出ます。追加時と更新時の両方で見ています。

```gdscript
if tracker.call(&"get_subsumed_by_plane") != null:
	_remove_plane(tracker_name)
	return
```

## 探索の間隔

`discover_plane_trackers()`は既定で**60フレームごと**に自動で呼ばれます。このサンプルは反応を優先して15にしています。

```gdscript
_extension.call(&"set_plane_tracker_discovery_cooldown", 15)
```

負の値にすると自動呼び出しが止まり、自分で好きなときに呼べます。

## 権限

`android.permission.SCENE_UNDERSTANDING_COARSE`が要ります。**Export presetに手で足す項目はありません** — `androidxr/trackables`が有効ならOpenXR Vendors pluginがmanifestへ入れ、起動時に要求もします。

権限が降りるまでトラッカーは来ないので、`are_permissions_granted()`が真になってから購読を始めています。

## 必要な設定

- `project.godot`: `xr/openxr/extensions/androidxr/trackables=true`（設定済み）
- OpenXR Vendors plugin
- Android XR用のExport preset

## 対応端末

Android XRのみ。非対応端末では理由を表示します。

## 単体で動かす

`samples/androidxr_planes/sample.tscn`をエディタで開いてF6。
