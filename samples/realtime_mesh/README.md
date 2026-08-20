# リアルタイム環境メッシュ

深度マップから、**毎フレーム更新される環境メッシュ**を作るサンプルです。CPUは一切使いません。

pinchで表示を切り替えます（格子線 ↔ 面）。

## 見どころ

`realtime_planes`はCPUへ深度を吸い出していますが、あれは**1秒に1回程度が限度**です。GPUからCPUへの転送が重く、深度マップ自体も毎フレーム更新されるわけではありません。

こちらは反対に、**深度テクスチャをシェーダーから直接読みます**。Vendorsプラグインは毎フレーム、次のグローバルuniformを更新しています。

```glsl
global uniform highp sampler2DArray META_ENVIRONMENT_DEPTH_TEXTURE;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT;
global uniform bool META_ENVIRONMENT_DEPTH_AVAILABLE;
```

やることは1つだけです。**格子メッシュを1枚置き、頂点シェーダーで各頂点を深度の位置へ飛ばします。**

```glsl
float depth = textureLod(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(uv, 0.0), 0.0).r;
vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
vec4 point = META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT * ndc;
VERTEX = point.xyz / point.w;
```

GDScript側は格子を作って`XROrigin3D`の下に置くだけで、毎フレームの処理はカメラ位置をuniformへ渡すことしかしていません。**更新はGPUが勝手にやります。**

## 実装で外せない点

**`[shader_globals]`の宣言。** グローバルuniformは`project.godot`の`[shader_globals]`に宣言が無いとシェーダーから参照できません。このリポジトリでは設定済みです。プラグイン同梱の`samples/meta-scene-sample/project.godot`に完全な一覧があります。

**`textureLod`を使う。** 頂点シェーダーには画面上の微分が無いため、`texture()`ではミップの選択ができません。明示的に`textureLod(..., 0.0)`で読みます。

**`extra_cull_margin`。** 頂点を動かしても、Godotが視界判定に使うAABBは元の`PlaneMesh`のままです。指定しないと、メッシュが視界内にあっても描画がまるごと省かれます。

**基準空間とワールド空間。** 逆行列が返すのはXRの基準空間の座標で、Godotのワールド座標ではありません。このノードを`XROrigin3D`の直下に置くことで、基準空間がそのままモデル空間になり、`VERTEX`へ入れるだけで済みます。`XROrigin3D`を動かしても追従します。

**物の縁。** 手前の物と奥の壁をまたぐ三角形は、そのままだと引き伸ばされた板になります。隣の頂点との距離が`edge_threshold`（既定0.15m）を超える頂点を落としています。それでも、有効な頂点と無効な頂点をまたぐ三角形の一部は残ります。

## 何に使えて、何に使えないか

| | このサンプル（GPU） | CPU経路 |
| --- | --- | --- |
| 更新頻度 | 毎フレーム | 1 Hz程度 |
| CPUコスト | ゼロ | それなり |
| 表示・シェーダー効果 | ○ | ○ |
| **当たり判定** | **✕** | ○ |

形がGPU上にしか無いので、**物理には使えません**。ボールを実際の机で跳ねさせたい場合はCPU経路が要ります。

オクルージョン（実物が仮想物体を隠す）は、このメッシュではなく[深度オクルージョン](../occlusion_depth/)のやり方が適切です。あちらは仮想物体側のフラグメントシェーダーで深度と比較するので、メッシュ化の誤差が入りません。

## 必要な設定

- `project.godot`: `xr/openxr/extensions/meta/environment_depth=true`（設定済み）
- `project.godot`: `[shader_globals]`にMeta深度のuniform宣言（設定済み）
- OpenXR Vendors plugin

## 対応端末

Quest 3のみ。非対応端末では理由を表示します。

Compatibility rendererで動きます。GLES3は頂点シェーダーからのテクスチャ参照と`sampler2DArray`に対応しています。

## 単体で動かす

`samples/realtime_mesh/sample.tscn`をエディタで開いてF6。
