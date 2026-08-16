# 深度オクルージョン

実物が仮想物体を隠すサンプルです。3つの立方体を0.6m / 1.2m / 2.0mに置いてあるので、手や物を前に出すと隠れます。

## 見どころ

**部屋のスキャンが要りません。** runtimeが毎フレーム作る深度マップを使うので、動いている物や人、後から持ち込んだ物にも効きます。事前スキャンのデータを読む[平面検出](../plane_detection/)とは性質が違います。

Godot側でやることは、ノードを1つ置くだけです。

```gdscript
_extension.call(&"start_environment_depth")
_depth_node = ClassDB.instantiate(&"OpenXRMetaEnvironmentDepth") as Node3D
_stage.origin.add_child(_depth_node)
```

`OpenXRMetaEnvironmentDepth`は`VisualInstance3D`を継承していて、描画時に深度マップとシーンの深度を比べてくれます。シェーダーを書く必要はありません。

- **手を深度から除く**設定をpinchで切り替えられます。ONにすると手は隠す側から外れるので、手で持っている仮想物体が手に隠されなくなります。runtimeが対応していて、かつコントローラーを使っていないときだけ効きます
- 深度マップの遅延は完全には消せません。速く動かすと輪郭がずれます

## 必要な設定

- `project.godot`: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）
- OpenXR Vendors plugin

## 対応端末

Quest 3（`XR_META_environment_depth`）。非対応端末では理由を表示します。Android XRには`OpenXRAndroidEnvironmentDepth`という別経路があり、こちらは未実装です。

## 単体で動かす

`samples/occlusion_depth/sample.tscn`をエディタで開いてF6。
