# 部屋メッシュ

事前スキャン済みの**部屋そのものの形**を取り出し、当たり判定と可視化を作るサンプルです。

pinchで表示のON/OFFを切り替えます。部屋データが無ければ、pinchでスキャン（Space Setup）を呼び出します。

## 平面検出との違い

| | [平面検出](../plane_detection/) | このサンプル |
| --- | --- | --- |
| 返るもの | 平面（境界つき） | 部屋の全要素＋**部屋全体の三角形メッシュ** |
| 家具 | 上面だけ | 箱として丸ごと |
| API | `XR_EXT_spatial_plane_tracking`（ベンダー非依存） | `XR_FB_scene`（Meta固有） |
| 当たり判定 | trackerが作る | `create_collision_shape()` |

平面検出はKhronos標準なので他社端末にも広がりますが、返るのは平面だけです。部屋の形が丸ごと欲しいなら、いまのところMetaのScene APIが要ります。

## 見どころ

要は`OpenXRFbSceneManager`です。**アプリ側はクエリも姿勢の追従も書きません。**

```gdscript
_manager = ClassDB.instantiate(&"OpenXRFbSceneManager")
_manager.set(&"default_scene", ANCHOR_SCENE)
_stage.origin.add_child(_manager)   # XROrigin3Dの直下でないと動かない
```

これだけで、検出した要素1つにつき1回`ANCHOR_SCENE`が作られ、`XRAnchor3D`の子として置かれ、`setup_scene(entity)`が呼ばれます。中身はこうです。

```gdscript
func setup_scene(entity: Object) -> void:
	var shape := entity.call(&"create_collision_shape") as Node   # 当たり判定
	var mesh := entity.call(&"create_mesh_instance") as MeshInstance3D  # 見た目
```

`create_mesh_instance()`は、三角形メッシュを持つ要素（部屋全体のメッシュ）ならそれを、持たない要素（壁・机）なら境界の箱や板を作って返します。**要素の種類で分岐する必要がありません。**

種類ごとに別のシーンを割り当てることもできます（`scenes/<semantic label>`）。プラグイン同梱のサンプルは`scenes/global_mesh`だけ差し替えています。このサンプルは1つのシーンで受けて、中で色を変えています。

## 実装で外せない点

**`XROrigin3D`の直下に置く。** マネージャは`get_parent()`を`XROrigin3D`にキャストし、失敗すると何もしません。プラグインのソースで確認できます。

**スキャン後は作り直す。** `openxr_fb_scene_capture_completed`が来ても、既存のアンカーは古いままです。`remove_scene_anchors()`と`create_scene_anchors()`を呼び直します。

**半透明にする。** 実世界を不透明な板で覆うとMRとして破綻します。この方針はリポジトリ全体で共通です。

## 意味ラベル

Metaが返す文字列です。要素の色分けに使っています。

`floor` / `ceiling` / `wall_face` / `invisible_wall_face` / `door_frame` / `window_frame` / `table` / `couch` / `bed` / `storage` / `screen` / `lamp` / `plant` / `wall_art` / `global_mesh` / `other`

`global_mesh`だけが部屋全体の三角形メッシュで、ほかは1つの家具や面です。

## オクルージョンについて

このメッシュで仮想物体を隠す（`occlusion_mesh`）ことは、**Godot 4.6のCompatibility rendererでは素直に書けません**。色を書かずに深度だけ書くマテリアルが作れないためです。詳しくは[調査メモ](../../docs/realtime_spatial_investigation.md)を参照してください。

実物で隠したい場合は[深度オクルージョン](../occlusion_depth/)を使ってください。仮想物体側のフラグメントシェーダーで深度と比較する方式なので、メッシュを経由しません。

## 必要な設定

- `project.godot`: `xr/openxr/extensions/meta/scene_api=true`、`meta/anchor_api=true`（設定済み）
- Export preset: Metaのpermission（`com.oculus.permission.USE_SCENE`）はpluginが自動で入れます
- 端末側でSpace Setup（部屋のスキャン）が済んでいること
- OpenXR Vendors plugin

## 対応端末

Quest 3のみ。非対応端末では理由を表示します。

## 単体で動かす

`samples/scene_mesh/sample.tscn`をエディタで開いてF6。
