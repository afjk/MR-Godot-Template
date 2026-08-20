# Android XRのリアルタイム環境メッシュ

OSが逐次更新する部屋のメッシュを、意味ラベル付きで受け取るサンプルです。

> **実機が無いため未検証です。** コードはOpenXR Vendors同梱のサンプルとプラグインのドキュメントに合わせてあります。

## 3つのメッシュの比較

| | [部屋メッシュ](../scene_mesh/) | [リアルタイム環境メッシュ](../realtime_mesh/) | このサンプル |
| --- | --- | --- | --- |
| 端末 | Quest 3 | Quest 3 | Android XR |
| データ源 | 事前スキャン | 深度から自作 | **OSが逐次更新** |
| 更新 | されない | 毎フレーム | 逐次 |
| 当たり判定 | ○ | ✕（GPU上のみ） | ○ |
| 意味ラベル | ○（要素ごと） | ✕ | **○（面ごと）** |

Quest 3では「事前スキャンで質を取るか、深度から自作してリアルタイムを取るか」の二択でした。Android XRは**両方が同時に手に入ります**。

## 見どころ: 差分で更新する

メッシュは小片（submesh）の集まりとして届き、それぞれに更新状態が付きます。

| 状態 | すること |
| --- | --- |
| `CREATED` | `MeshInstance3D`を作る |
| `UPDATED` | `ArrayMesh`を作り直す |
| `UNCHANGED` | **何もしない**（姿勢だけ入れ直す） |
| `DELETED` | 消す |

**全部作り直してはいけません。** 部屋のメッシュは小片が数十個になるので、毎回`ArrayMesh`を作り直すと現実的な負荷になりません。`UNCHANGED`を素通しするのが要点です。

```gdscript
if state == UPDATE_STATE_UNCHANGED:
	continue

var mesh := ArrayMesh.new()
mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data.call(&"get_arrays"))
instance.mesh = mesh
```

姿勢（`get_transform()`）は`UNCHANGED`でも入れ直します。形が変わらなくても位置は補正されるためです。

## 問い合わせの範囲

`get_submesh_data(pose, extents)`は、指定した箱の中にある小片を返します。このサンプルは視線の3m先を中心に6×4×6mを見ています。範囲を広げるほど返る小片が増えるので、必要なぶんだけにしてください。

## 意味ラベル

`initialize()`に`SEMANTIC_LABEL_SET_DEFAULT`を渡すと、面ごとに`floor` / `ceiling` / `wall` / `table` / `other`が付きます。対応は端末次第なので、`get_supported_semantic_label_sets()`で確かめてから渡します。

ラベルは`get_vertex_semantics()`（頂点ごと）または`get_indexed_vertex_semantics()`で取れます。このサンプルは形の表示までで、色分けはしていません。

## 権限

`android.permission.SCENE_UNDERSTANDING_FINE`が要ります（`COARSE`では足りません）。`androidxr/scene_meshing`が有効ならOpenXR Vendors pluginがmanifestへ入れ、起動時に要求もします。

## 必要な設定

- `project.godot`: `xr/openxr/extensions/androidxr/scene_meshing=true`（設定済み）
- OpenXR Vendors plugin
- Android XR用のExport preset

## 対応端末

Android XRのみ。非対応端末では理由を表示します。

## 単体で動かす

`samples/androidxr_scene_mesh/sample.tscn`をエディタで開いてF6。
