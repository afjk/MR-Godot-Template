# リアルタイム平面認識・メッシュ生成の調査

「AR Foundationのような平面認識とメッシュ生成」をQuest 3で実現できるか、できるとしたら何を使うのかを調べた記録です。

## 1. 結論

**Quest 3には、OSレベルのリアルタイム平面検出がありません。AR Foundationを使っても同じです。**

Unityの公式ドキュメント（Meta OpenXR package）にこう書かれています。

> Unlike other AR platforms, Meta OpenXR does not dynamically detect trackables at runtime. Instead, Meta's OpenXR runtime queries the device's Space Setup data and returns information stored in its Scene Model.

つまりUnity + AR Foundation + Quest 3の`ARPlaneManager`も、**Space Setupで事前スキャンした部屋データを返しているだけ**です。ARCore/ARKitのような「見た平面がその場で生えてくる」挙動は、スマホARの機能であって、Quest 3のOSは提供していません。しかもMeta OpenXR packageが対応する分類は、上向き水平面の`Couch` / `Table` / `Floor`のみです。

**私たちの`plane_detection`サンプルは、AR FoundationのQuest実装と同等のことをしています。** 「AR Foundationのようになっていない」のではなく、AR Foundation自体がQuestではそういう作りです。

では本当のリアルタイムは不可能かというと、そうではありません。**材料はDepth APIとして公開されており、平面抽出とメッシュ化を自分で書けば実現できます。** 以下はその実現方法の調査です。

**なお、これはQuest 3の話です。PICO 4 UltraとAndroid XRはOSがリアルタイム平面とメッシュを提供します。** PICOについては第3節にまとめました。「AR Foundationのような」ものが欲しいなら、実はPICO 4 Ultraのほうが近道です。

## 2. 端末ごとの実態

| 端末 | リアルタイム平面 | リアルタイムメッシュ | 材料 |
| --- | --- | --- | --- |
| **Quest 3 / 3S** | ✕ OSは提供しない | ✕ 部屋メッシュは事前スキャン | ○ `XR_META_environment_depth`（深度マップ） |
| **Android XR** | ○ `XR_ANDROID_trackables` | ○ `XR_ANDROID_scene_meshing` | ○ `XR_ANDROID_depth_texture` |
| **PICO 4 Ultra** | ○ `XR_BD_spatial_plane` | ○ `XR_BD_spatial_mesh`（意味ラベル付き） | — |
| VIVE Focus Vision | ✕ | ✕ | ✕ |

**Android XRとPICO 4 Ultraは、本当にAR Foundation相当のものがOSから来ます。** Android XRについてはGodot OpenXR Vendorsが`OpenXRAndroidTrackablePlaneTracker`と`OpenXRAndroidSceneMeshing`を公開済みで、こちらは実装するだけです（実機が無いので未検証）。PICOについては第3節にまとめました。

Quest 3では深度マップを自分で処理するしかありません。第4節以降はその話です。

## 3. PICO 4 Ultraは事情が違う

PICO 4 Ultraでは、Unity Integration SDKにPlane Detectionがあります（[v3.4.0](https://github.com/Pico-Developer/PICO-Unity-Integration-SDK/releases), 2026-02-27）。

> Added plane detection functionality. With plane detection, MR applications can identify and track horizontal, vertical, or inclined surfaces (such as floors, desktops, walls, and sloped roofs).

Unity SDKにしか無いなら、Godotからは手が出ないように見えます。**しかしOpenXRのレジストリを見ると、同じ機能がByteDanceのベンダー拡張として公開されています。** Unity SDKはそのruntime機能をUnity向けに包んだものであって、機能そのものはOpenXRの層にあります。

### レジストリで確認できる拡張

`OpenXR-SDK/specification/registry/xr.xml`を直接引いて確認しました（拡張番号とspec versionは同ファイルより）。

| 拡張 | 番号 | 内容 |
| --- | --- | --- |
| `XR_BD_spatial_sensing` | 390 | 空間エンティティの基盤。他のBD拡張は全てこれに依存する |
| `XR_BD_spatial_anchor` | 391 | 任意位置のアンカー生成と永続化 |
| `XR_BD_spatial_anchor_sharing` | 392 | アンカーの共有 |
| `XR_BD_spatial_scene` | 393 | シーンキャプチャ（事前スキャン） |
| `XR_BD_spatial_mesh` | 394 | **空間メッシュ**。LODと意味ラベル付き |
| `XR_BD_spatial_plane` | 397 | **平面検出**。向きによる絞り込み付き |

仕様本体はOpenXR 1.1.50（2025-07-24）で公開されています。**平面もメッシュもアンカーも、OpenXR拡張として存在します。**

### APIの形

Metaの`XR_FB_scene`ともKhronosの`XR_EXT_spatial_entity`とも違う、**sense data provider**という独自の形です。

```
xrCreateSenseDataProviderBD(type)     // PLANE_BD / MESH_BD / SCENE_BD / ANCHOR_BD
xrStartSenseDataProviderAsyncBD()
  → XR_TYPE_EVENT_DATA_SENSE_DATA_UPDATED_BD が届く
xrQuerySenseDataAsyncBD(filter)       // UUID・意味ラベル・平面の向きで絞れる
xrGetQueriedSenseDataBD()             // エンティティIDの一覧
xrGetSpatialEntityComponentDataBD()   // 1エンティティのコンポーネントを引く
```

エンティティが持つコンポーネントは7種類です。

`LOCATION` / `SEMANTIC` / `BOUNDING_BOX_2D` / `POLYGON` / `BOUNDING_BOX_3D` / `TRIANGLE_MESH` / `SPHERE`

`XR_BD_spatial_plane`はこれに`PLANE_ORIENTATION`を足します。値は`HORIZONTAL_UPWARD`（床）、`HORIZONTAL_DOWNWARD`（天井）、`VERTICAL`（壁）、`ARBITRARY`（斜面）。**AR Foundationの`PlaneAlignment`とそのまま対応します。**

意味ラベルは25種類あり、Metaより細かいです。

> `FLOOR` / `CEILING` / `WALL` / `DOOR` / `WINDOW` / `OPENING` / `TABLE` / `SOFA` / `CHAIR` / `HUMAN` / `BEAM` / `COLUMN` / `CURTAIN` / `CABINET` / `BED` / `PLANT` / `SCREEN` / `VIRTUAL_WALL` / `REFRIGERATOR` / `WASHING_MACHINE` / `AIR_CONDITIONER` / `LAMP` / `WALL_ART` / `STAIRWAY` / `UNKNOWN`

### メッシュはリアルタイムで、しかもセグメンテーション付き

`XR_BD_spatial_mesh`には`XR_SPATIAL_MESH_CONFIG_SEMANTIC_BIT_BD`があり、さらに`XR_SPATIAL_MESH_CONFIG_ALIGN_SEMANTIC_WITH_VERTEX_BIT_BD`で**意味ラベルを頂点単位に付けるか三角形単位に付けるか**を選べます。LODは`COARSE` / `MEDIUM` / `FINE`。

PICO自身のSDKドキュメントもSpatial Meshをこう説明しています。

> dynamically scan the real-world scene in real-time

つまり**PICO 4 Ultraでは、Quest 3でできなかった「リアルタイムのメッシュ生成」と「意味によるセグメンテーション」が、OSから直接来ます**。私たちが第4節以降でQuest 3向けに自作しようとしているものが、PICOでは標準機能です。

### ではGodotから使えるのか

3つの経路があります。

**経路1: Godot 4.6 coreのSpatial Entities（`XR_EXT_spatial_*`）— 追加実装ゼロ**

Khronosの発表で、PICOのOpenXR Tech LeadであるZhipeng Liu氏がこう述べています。

> As the first vendor to provide runtime implementation support for the integration and validation of Spatial Entities, PICO takes great pride in collaborating with Godot to deliver enhanced cross-platform spatial perception development experiences to the broader XR developers.

**PICOはKhronos標準のSpatial Entitiesを最初に実装したベンダーで、しかもGodotの実装検証に協力しています。** Godot側の実装者も「公開runtimeがまだ無いのでベータで検証した」と書いており、そのベータの出所はここだと考えるのが自然です。

つまり**このリポジトリの[`plane_detection`](../samples/plane_detection/)サンプルは、PICO 4 Ultraでそのまま動く可能性が高い**、ということです。コードを1行も足さずに確認できるので、これを最初にやるべきです。

**経路2: `XR_BD_*`をGDExtensionで包む — 要C++**

Godot OpenXR Vendorsの`doc_classes/`を全件確認しましたが（84ファイル）、`OpenXRBd*`にあたるクラスは1つもありません。PICO関連のissueもゼロです。**誰もまだ書いていません。**

書くなら、上のAPI一覧がそのまま設計図になります。仕様は公開されているので、解析は不要です。既存の`OpenXRAndroidTrackablePlaneTracker`や`OpenXRFbSceneManager`と同じ形（`XRServer`のanchorトラッカーとして出す）に合わせれば、サンプル側のコードは平面検出とほぼ共通にできます。

**経路3: Unity Integration SDKのネイティブ層を直接叩く — やらない**

Unity SDKはUnity専用のラッパーで、その下にあるのは結局同じruntime機能です。**Godotから同じものへ届く正規の入口が経路1・2なので、こちらを選ぶ理由はありません。**

### 結論

1. まず`plane_detection`と`floor_detection`をPICO 4 Ultra実機で試す。**動けば実装は不要**
2. 動かなければ、`XR_BD_spatial_sensing` + `XR_BD_spatial_plane`をGDExtensionで包む
3. `XR_BD_spatial_mesh`は、Quest 3向けの自作メッシュ（S1・S2）より確実で高品質。PICOを重視するならこちらが本命

## 4. Quest 3の深度マップで何ができるか

`XR_META_environment_depth`は、Godot OpenXR Vendors経由で**2通りに公開されています**。この2つを使い分けるのが要点です。

### 経路A: GPU（グローバルシェーダーuniform）

プラグインは毎フレーム、次のグローバルuniformを更新しています（プラグイン本体のソースで確認）。

```glsl
global uniform highp sampler2DArray META_ENVIRONMENT_DEPTH_TEXTURE;
global uniform highp vec2 META_ENVIRONMENT_DEPTH_TEXEL_SIZE;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT;  // 右も同様
global uniform highp mat4 META_ENVIRONMENT_DEPTH_FROM_CAMERA_PROJECTION_LEFT;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_TO_CAMERA_PROJECTION_LEFT;
global uniform bool META_ENVIRONMENT_DEPTH_AVAILABLE;
```

**深度テクスチャに直接アクセスできるということは、頂点シェーダーで格子メッシュを変位させられる**ということです。

- 格子（例: 128×128の`PlaneMesh`）を1枚用意する
- 頂点シェーダーで、各頂点のUVから深度を読み、逆行列でワールド座標へ飛ばす
- 結果は**毎フレーム更新される環境メッシュ**。CPUコストはほぼゼロ

これは「見た目のメッシュ」（可視化、オクルージョン、シェーダー効果）には完全に有効です。**当たり判定には使えません**（GPU上にしかデータが無いため）。

Compatibility rendererでも動きます。プラグイン同梱のシェーダー自身が`#if CURRENT_RENDERER != RENDERER_COMPATIBILITY`で分岐しており、Compatibilityを想定した作りになっています。GLES3は頂点シェーダーからのテクスチャ参照（vertex texture fetch）とsampler2DArrayに対応しています。

> 必要な準備: `project.godot`の`[shader_globals]`に上記のuniformを宣言する必要があります。プラグインのサンプル（`samples/meta-scene-sample/project.godot`）に完全な一覧があり、そのまま持ってこられます。**このリポジトリにはまだ入っていません。**

### 経路B: CPU（`get_environment_depth_map_async`）

```gdscript
_extension.call(&"get_environment_depth_map_async", _on_depth_map)
# → 左右ぶんの { image: Image, depth_projection_view, depth_inverse_projection_view }
```

プラグインのドキュメント自身が「独自のrealtime plane trackingの実装に使える」と書いている経路です。ただし**1秒に1回程度**が推奨で、毎フレームは不可（深度マップの更新自体が2〜4フレームに1回、加えてGPU→CPU転送が重い）。

こちらは当たり判定と平面クラスタリングに使えます。

### 使えないもの: compute shader

Godotのcompute shaderには`RenderingDevice`が必要で、**Compatibility rendererには存在しません**。GPUで本格的な点群処理（法線推定、クラスタリング）をやるならMobile renderer（Vulkan）へ切り替えることになります。これはプロジェクト全体に関わる判断なので、いまは選択肢として置いておきます。

## 5. 実現方法の設計（Quest 3）

以上から、Quest 3で「平面認識＋メッシュ生成」を成立させる構成はこうなります。

| やりたいこと | 経路 | 更新頻度 | 実装量 |
| --- | --- | --- | --- |
| 環境メッシュの**表示**・オクルージョン | A（頂点シェーダー） | 毎フレーム | 小（シェーダー30行程度） |
| 環境メッシュの**当たり判定** | B（CPU）→`ConcavePolygonShape3D` | 0.5〜1 Hz | 中 |
| **平面の検出**（複数枚、境界つき） | B（CPU）→ 法線推定 → クラスタリング → 多角形化 | 0.5〜1 Hz | 大 |
| 平面の**追跡**（フレーム間の同一性） | B + 自前の照合 | 同上 | 中 |

### 平面検出の中身（ARCoreがやっていること）

自分で書く場合、手順はこうなります。

1. **点群化**: 深度マップを間引いて（例: 80×60）ワールド座標へ戻す。既存の`realtime_planes`で実装済み
2. **法線推定**: 格子の隣接差分から各点の法線を出す。これも実装済み（1点ぶんだけ）
3. **クラスタリング**: 法線の向きと平面までの距離`d = n·p`が近い点をまとめる。格子構造があるので領域拡張（region growing）が素直
4. **平面フィット**: 各クラスタでPCAまたは最小二乗
5. **境界の多角形化**: 平面座標へ射影して凸包、または軸並行の矩形
6. **追跡**: 前フレームの平面と`(n, d)`が近ければ同一とみなして更新・統合

GDScriptで80×60 = 4,800点なら、1 Hzで回す限り現実的です。実測して重ければ、間引きを増やすか、GDExtension（C++）に移します。

### 精度の限界（Metaのドキュメントより）

- 有効範囲は**約0.2m〜4m**。それより近い/遠いと信頼できない
- 動くものにも反応する反面、ノイズが乗る。事前スキャンの平面のような安定性は出ない
- 手を除外する設定（`set_hand_removal_enabled`）があるので、手を面と誤認しないようにできる

## 6. 提案する進め方

3本に分けます。1本目が最も確実で、効果も分かりやすいので先に作ります。

### S1: `realtime_mesh`（環境メッシュの表示・オクルージョン）

- `[shader_globals]`を整備し、格子メッシュ＋頂点シェーダーで**毎フレーム更新される環境メッシュ**を出す
- 表示モードを切り替えられるようにする: ワイヤーフレーム／不可視（深度のみ書いてオクルーダーにする）
- **これで「メッシュ生成」は目に見える形で達成できます**。CPUを使わないので性能面の心配もありません

### S2: `realtime_mesh_collision`（当たり判定）

- CPU経路で深度を落とし、間引いた格子から`ArrayMesh`と`ConcavePolygonShape3D`を作る
- 1 Hz更新、フレーム分散。ボールを投げて実際の床や机で跳ねるところまで

### S3: `realtime_plane_clusters`（複数平面の検出）

- 第5節の手順を実装。検出した平面を色分け＋境界表示、フレーム間で追跡
- ここまで来ると、**Quest 3で「動かした机がその場で平面として出る」**が実現します

### 別枠: `androidxr_trackables`

- Android XRのネイティブ経路（`OpenXRAndroidTrackablePlaneTracker` / `OpenXRAndroidSceneMeshing`）
- 実機が無いため未検証のまま入れることになります。コードは書けます

### 別枠: PICO 4 Ultra

- まず既存サンプルを実機で試す（コード不要）
- 必要なら`XR_BD_spatial_plane` / `XR_BD_spatial_mesh`のGDExtension。第3節参照

## 7. 決めたいこと

1. **PICO 4 Ultra実機での確認**。`plane_detection`が動くかどうかで、以降の作業量が大きく変わります。**最優先**
2. **S1から着手**でよいか（推奨）。S1は確実に動き、S2・S3の土台にもなります
3. **S3の実装言語**: まずGDScriptで書いて実測し、重ければGDExtensionへ。この方針でよいか
4. **renderer**: compute shaderが必要になった場合、Mobile rendererへの切り替えを検討するか。現状はCompatibilityのままで進められる見込みです
5. **Android XR経路**: 実機無しでコードだけ入れるか、実機が手に入るまで保留するか
6. **`XR_BD_*`のGDExtension**: 書くとしたら、このリポジトリに置くか、Godot OpenXR Vendorsへ提案するか

## 参考

- [Unity OpenXR Meta — Session（Meta OpenXRは実行時に検出しない旨）](https://docs.unity3d.com/Packages/com.unity.xr.meta-openxr@1.0/manual/features/session.html)
- [Meta Depth API Overview（有効範囲0.2〜4m）](https://developers.meta.com/horizon/documentation/unity/unity-depthapi-overview/)
- [Godot OpenXR Vendors — `OpenXRMetaEnvironmentDepthExtension`](https://github.com/GodotVR/godot_openxr_vendors/blob/master/doc_classes/OpenXRMetaEnvironmentDepthExtension.xml)
- [同 — 再投影シェーダーとグローバルuniformの実装](https://github.com/GodotVR/godot_openxr_vendors/blob/master/plugin/src/main/cpp/extensions/openxr_meta_environment_depth_extension.cpp)
- [同 — `meta-scene-sample`の`[shader_globals]`宣言](https://github.com/GodotVR/godot_openxr_vendors/blob/master/samples/meta-scene-sample/project.godot)
- [XR_ANDROID_trackables（Android XRのリアルタイム平面）](https://developer.android.com/develop/xr/openxr/extensions/XR_ANDROID_trackables)
- [XR_ANDROID_scene_meshing（同、逐次更新メッシュ）](https://developer.android.com/develop/xr/openxr/extensions/XR_ANDROID_scene_meshing)
- [OpenXRレジストリ`xr.xml`（`XR_BD_*`の定義本体）](https://github.com/KhronosGroup/OpenXR-SDK/blob/main/specification/registry/xr.xml)
- [OpenXR-Docs CHANGELOG（`XR_BD_spatial_*`の追加履歴）](https://github.com/KhronosGroup/OpenXR-Docs/blob/main/CHANGELOG.Docs.md)
- [PICO Unity Integration SDK リリースノート（Plane Detectionの追加）](https://github.com/Pico-Developer/PICO-Unity-Integration-SDK/releases)
- [PICO Unity OpenXR SDK リリースノート（Spatial Meshのリアルタイム記述）](https://github.com/Pico-Developer/PICO-Unity-OpenXR-SDK/releases)
- [Khronos: Godot OpenXR Integration Project Update（PICOのSpatial Entities実装コメント）](https://www.khronos.org/blog/godot-openxr-integration-project-update-major-openxr-features-now-production-ready)
- [OpenXR: Add support for spatial entities extension（Godot本体のPR）](https://github.com/godotengine/godot/pull/107391)
