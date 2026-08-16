# 空間認識（AR Foundation相当）の検討メモ

床面検知・環境メッシュ・セグメンテーションを、このテンプレートへどう入れるかの方針メモです。実装はまだ行っていません。インタラクション基盤側の検討は[docs/mr_toolkit_design.md](mr_toolkit_design.md)にあります。

- 対象: Godot 4.6 / Compatibility renderer / OpenXR / Quest 3・PICO 4 Ultra・VIVE Focus Vision・Android XR
- 呼称: MRGTの空間認識層（`addons/mrgt/spatial/`）

> **位置づけの更新**: このリポジトリはサンプル集として育てる方針になりました（[docs/samples_plan.md](samples_plan.md)）。空間認識の各機能は、まず`samples/floor_detection/`のような**個別サンプルとして実装**し、共通化はその後です。第4節の正規化層は抽出先の設計として、第3節の端末マトリクスと第7節のセグメンテーションの整理は、サンプルの取捨選択の根拠として使います。

## 1. 結論の要約

| 論点 | 方針 |
| --- | --- |
| 全体 | Godotに**AR Foundation相当の統一抽象は無い**。バックエンド3系統を薄い自前層で束ねる |
| バックエンド | ①Godot 4.6 coreのSpatial Entities ②OpenXR VendorsのMeta系 ③同Android XR系 |
| 設計の中心 | 「取れる／取れない」を実行時に問い合わせる**capability API**。無い端末で壊れないことを最優先 |
| 床面検知 | 平面API → 環境メッシュ → Local Floorのy=0、の**3段構え**で全機種に必ず答えを返す |
| 環境メッシュ | Meta（Scene mesh）とAndroid XRのみ。物理は「周辺チャンクのみ」、描画は原則オクルージョン専用 |
| セグメンテーション | **3層に分けて扱う**（意味ラベル／深度オクルージョン／ピクセル単位）。A・Bを採用、Cは研究枠 |
| 最初にやること | capability検出＋床面検知＋デバッグ可視化 |

AR Foundationの`ARPlaneManager`のような「どの端末でも同じAPI」は、Godotでは**自分で作る部分**です。逆に言えば、作るのは薄い正規化層だけで、実データはcoreとVendorsが提供します。

## 2. AR Foundationとの対応

| AR Foundation | 相当するもの（Godot） | 状況 |
| --- | --- | --- |
| `ARPlaneManager` | core Spatial Entities（`OpenXRPlaneTracker`）／`OpenXRAndroidTrackablePlaneTracker`／Metaの`OpenXRFbSceneManager` | 3経路あり、要正規化。core経路は`samples/plane_detection/`で実装済み |
| `ARMeshManager` | `OpenXRAndroidSceneMeshing`／`OpenXRMetaSpatialEntityMeshExtension` | Quest 3とAndroid XRのみ |
| `AROcclusionManager`（environment depth） | `OpenXRMetaEnvironmentDepth`／`OpenXRAndroidEnvironmentDepth` | Quest 3とAndroid XRのみ |
| `AROcclusionManager`（human segmentation） | **相当機能なし** | iOS/ARKit固有。standalone MRには無い（第7節C） |
| `ARAnchorManager` | core Spatial Entities（anchor）／`OpenXRFbSpatialAnchorManager`／`OpenXRAndroidAnchorTracker` | 永続化は`OpenXRFbSpatialEntityStorage`／`OpenXRAndroidDeviceAnchorPersistence` |
| `ARRaycastManager` | `OpenXRAndroidRaycastExtension`／他は自前（平面・メッシュへの`RayCast3D`） | 正規化対象 |
| `ARTrackedImageManager` | core Spatial Entities（marker）／`OpenXRMlMarkerUnderstanding` | QRマーカー中心 |
| `ARCameraManager`（light estimation） | `OpenXRAndroidLightEstimation` | Android XRのみ |
| `ARCameraManager`（CPU画像） | Quest: Passthrough Camera API（Camera2経由）／Android XR: `OpenXRAndroidPassthroughCameraStateExtension` | 権限と審査が絡む（第7節C） |
| `ARSession` / trackable lifecycle | 自前（`MRGTSpatialManager`） | **ここが作る部分** |

## 3. 端末ごとに何が取れるか

OpenXR Vendors pluginが公開しているクラス（`doc_classes/`）から読み取れる現状です。実際に動くかはruntimeのバージョンにも依存するため、**実行時判定を前提**にします。

| 機能 | Quest 3 | PICO 4 Ultra | VIVE Focus Vision | Android XR |
| --- | --- | --- | --- | --- |
| 平面 | ○ Meta Scene | △ core EXT次第（要実機確認） | ✕ | ○ Trackables |
| 環境メッシュ | ○ Scene mesh（事前スキャン） | ✕（要確認） | ✕ | ○ Scene Meshing（逐次更新） |
| 深度（オクルージョン） | ○ `OpenXRMetaEnvironmentDepth` | ✕ | ✕ | ○ `OpenXRAndroidEnvironmentDepth` |
| アンカー／永続化 | ○ | △ core EXT次第 | ✕ | ○ |
| マーカー（QR） | △ core EXT次第 | △ | ✕ | ○ |
| ライト推定 | ✕ | ✕ | ✕ | ○ |
| カメラ画像 | △ Passthrough Camera API（権限必須） | ✕ | ✕ | △ |

VIVE Focus Visionは、Vendors pluginが`OpenXRHtcPassthroughExtension`と顔追跡しか公開しておらず、**空間認識は現状ゼロ**です。PICO 4 Ultraも専用クラスが無いため、Godot 4.6 coreのSpatial Entities（`XR_EXT_spatial_*`）をruntimeが公開していれば動く、という位置づけになります。Khronosの発表ではMeta・Google・PICO・Varjoが対応を表明しているので、**時間が解決する可能性はありますが、今は前提にできません**。

この非対称性が設計をほぼ決めます。**「取れない端末で何を見せるか」がAPIの主要な設計対象**です。

## 4. アーキテクチャ方針

### 層構成

```text
addons/mrgt/spatial/
  mrgt_spatial_manager.gd     Autoload。capability問い合わせと正規化データの発行
  types/                      MRGTPlane, MRGTSceneMesh, MRGTAnchor, ラベルenum
  backends/
    backend_core_entities.gd  Godot 4.6 core Spatial Entities
    backend_meta_scene.gd     OpenXRFbSceneManager / OpenXRMetaSpatialEntityMesh
    backend_androidxr.gd      OpenXRAndroidTrackable* / SceneMeshing
    backend_fallback.gd       Local Floorのy=0など、最後の手段
  occlusion/                  深度オクルージョン、メッシュのオクルーダー材質
  debug/                      平面・メッシュ・ラベルの可視化
```

バックエンドは**起動時に1つ選ぶのではなく、機能単位で選びます**。「平面はMeta Scene、深度はMeta Depth、マーカーはcore」のような組み合わせが普通に起こるためです。`samples/controller_models/sample.gd`がrender modelでcoreとMeta経路を両方用意して実際に返した方を採る作りになっているので、その考え方をそのまま広げます。

### capability API

```gdscript
enum Capability { PLANES, SCENE_MESH, DEPTH, ANCHORS, ANCHOR_PERSISTENCE, MARKERS, LIGHT_ESTIMATION }

## その端末で実際に使えるか。UI側はこれを見て機能を出し分ける。
func has_capability(cap: Capability) -> bool

## 権限やスキャン状態を含む、より詳しい状態。
enum Availability { UNSUPPORTED, PERMISSION_REQUIRED, NEEDS_SETUP, READY }
func get_availability(cap: Capability) -> Availability
```

`NEEDS_SETUP`は「Quest 3だがSpace Setupをまだ実行していない」状態です。この場合はアプリからScene Capture（`OpenXRFbSceneCaptureExtension`）を要求してユーザーを部屋スキャンへ誘導できます。**空の結果とセットアップ未完了を区別できること**が実用上いちばん効きます。

### 正規化データ

```gdscript
class_name MRGTPlane
extends Node3D

enum Label { UNKNOWN, FLOOR, CEILING, WALL, TABLE, COUCH, DOOR, WINDOW, SCREEN, OTHER }

var id: StringName
var label: Label
var extent: Vector2          ## 中心からの寸法
var boundary: PackedVector2Array  ## 取得できる場合の輪郭
var confidence: float
var source: StringName       ## "meta_scene" / "androidxr" / "core" / "fallback"
```

signalは`plane_added(plane)` / `plane_updated(plane)` / `plane_removed(id)`の3つに統一します。AR Foundationの`trackablesChanged`と同じ形です。Metaのsemantic label（`FLOOR`、`WALL_FACE`、`TABLE`…）とAndroid XRのplane label は語彙が違うので、**変換表をコード側に一箇所だけ持ちます**。

座標はすべて`XROrigin3D`相対で扱い、recenter（`pose_recentered`シグナル、既にテンプレートが中継済み）を受けたら再取得します。

## 5. 床面検知

MRで最初に必要になり、かつ全機種で何かしら答えを返せる唯一の機能なので、**最優先**にします。

3段構えです。

1. **平面API**: `floor`ラベルの平面。coreの`OpenXRPlaneTracker`、Metaのscene entity、Android XRのTrackablesのいずれか
2. **環境メッシュ**: 平面が無い場合、メッシュ内の最下位の水平面を推定
3. **Local Floor**: どちらも無い場合、reference spaceがLocal Floorなので**`y = 0`が床**。このプロジェクトは既に`xr/openxr/reference_space=2`でこれを使っています

> 実装メモ（`samples/floor_detection/`）: 1と3、およびMetaのscene entity経路を実装しました。2（環境メッシュからの推定）は、メッシュ取得そのものが未実装のため入っていません。**「指先で高さを指定する」手動設定は検知ではない**ため、このサンプルからは外しています。アプリ側で用意するのは構いませんが、床面検知の説明に混ぜると誤解を招きます。

```gdscript
class_name MRGTFloor

var height: float          ## XROrigin3D空間でのy
var normal: Vector3
var source: StringName     ## どの段で得たか
var confidence: float
```

3段目は「検知」ではなく「仮定」ですが、**PICOとVIVEではこれが唯一の答え**になります。出所（`source`）を返す設計にしておけば、アプリ側は「精度が要る処理は`source != "fallback"`のときだけ」と書けます。ユーザーが手で高さを微調整できるUIも用意します。

受け入れ条件: 4機種すべてで床の高さが返り、その上に立方体を置いて沈まない・浮かないこと。Quest 3では実際の床の高さと5cm以内で一致すること。

## 6. 環境メッシュ

### 取得の性質が端末で違う

- **Quest 3**: 事前のSpace Setupで作られた**静的な**部屋メッシュ。起動時に一度取れば基本変わらない
- **Android XR**: **逐次更新される**メッシュ。サブメッシュ（`OpenXRAndroidSceneSubmeshData`）が随時追加・更新される

前者は「読み込んで終わり」、後者は「更新を捌き続ける」ので、**更新の流量制御**を層の側に持たせます。1フレームに処理するサブメッシュ数に上限を設け、`ConcavePolygonShape3D`の生成は分散させます。

### 物理

全メッシュにcollisionを張るとCompatibility renderer・モバイルGPUの構成では厳しくなります。二段構えにします。

- 既定: **平面のみ**collision（床・壁・机）。多くの用途はこれで足りる
- 任意: ユーザー周辺N mのメッシュチャンクだけcollision化し、離れたら破棄

### 描画とオクルージョン

環境メッシュは原則**表示しません**。役割はオクルージョン（実物が仮想を隠す）です。

本テンプレートはAlpha blendでパススルーを出しているため、**「深度だけ書いてカラーは透明」なマテリアルでメッシュを描けば、その背後の仮想物体が隠れてパススルーが見える**はずです。ただしCompatibility rendererでの深度書き込みと透明描画順の扱いは実機で確認が要ります。第一マイルストーンの検証項目に入れます。

デバッグ用にワイヤーフレーム表示を出せるようにしておきます。

## 7. セグメンテーション

「セグメンテーション」は指すものが3つあり、実現性がまったく違うので分けて扱います。

| 層 | 内容 | 実現手段 | 対応 | 判断 |
| --- | --- | --- | --- | --- |
| **A. 意味ラベル** | 平面・物体に「床／壁／机／ソファ」等の意味を付ける | Meta Sceneのsemantic label、Android XRのplane label＋`OpenXRAndroidTrackableObjectTracker` | Quest 3 / Android XR | **採用** |
| **B. 深度オクルージョン** | 実物（手・人・家具）が仮想物体を隠す | `OpenXRMetaEnvironmentDepth` / `OpenXRAndroidEnvironmentDepth` | Quest 3 / Android XR | **採用**（`samples/occlusion_depth/`で実装済み） |
| **C. ピクセル単位** | 任意物体・人物のマスクを画素単位で得る | Passthrough Camera API（Camera2）＋端末上のML推論 | Quest 3のみ | 研究枠 |

### A: 意味ラベル（安価で用途が広い）

第4節の`MRGTPlane.label`がそのまま該当します。「机の上にパネルを置く」「壁に貼る」「床にだけ落とす」は、これで実装できます。**MRらしい挙動の大半はAで足ります。**

### B: 深度オクルージョン（見た目への寄与が最大）

環境深度マップで仮想物体を遮蔽します。メッシュによるオクルージョン（第6節）との違いは、**動くもの（手・人・持ち込まれた物）にも効く**ことです。Vendors pluginはCPU側から深度マップを取得するメソッドも持っています。

> 実装メモ: Metaについては`OpenXRMetaEnvironmentDepth`（`VisualInstance3D`）を置くだけで遮蔽が効きました（`samples/occlusion_depth/`）。シェーダーを書く必要はありません。CPU側の`get_environment_depth_map_async()`は、事前スキャンに頼らないリアルタイムの平面推定に使えます（`samples/realtime_planes/`）。**平面APIが返すデータが事前スキャンかリアルタイムかはruntime依存**で、Quest 3では前者です。この違いは利用者にとって大きいので、サンプルを分けています。

- 実装は「深度テクスチャを受け取り、シーンの深度と比較して破棄する」シェーダー経路になります
- **Compatibility rendererで深度テクスチャをシェーダーへ渡せるか**が最大の技術的未確認点です。ここが通らない場合、Bはメッシュオクルージョン止まりになります
- 手だけならHand Trackingの関節から簡易メッシュを作って遮蔽する代替手段があります（`OpenXRFbHandTrackingMesh`も利用可）

### C: ピクセル単位（範囲を明確に区切る）

AR Foundationのhuman segmentation stencilはiOS固有機能で、**standalone MRのOpenXRには相当機能がありません**。同じことをやるなら、パススルーカメラ画像を取得して自前で推論するしかありません。

- Quest 3は`horizonos.permission.HEADSET_CAMERA`でCamera2経由の画像取得が可能（ストアアプリでも利用可）
- Godot側はAndroidのカメラ対応（4.5以降）を使う先行事例があるものの、**推論を回すならGDExtensionが要る**
- 解像度・レイテンシ・電池・プライバシー審査が重く、テンプレートに常設する性質のものではない

**方針**: Cはテンプレート本体には入れず、必要になった時点で別サンプル／別リポジトリとして扱います。この判断をメモに残しておくこと自体が目的です。

## 8. ロードマップ

インタラクション側（`mr_toolkit_design.md`のM0-M4）とは独立に進められます。

### S1: 基盤と床面

- `MRGTSpatialManager`、capability／availability API、権限要求フロー
- 床面検知の3段構え、デバッグ可視化（床グリッド）
- 受け入れ: 4機種で床が返る。未対応端末でもクラッシュせず`fallback`と表示される

### S2: 平面と配置

- 平面の取得・正規化・ラベル、追加／更新／削除のsignal
- 平面へのレイキャストと配置（インタラクション側のTapToPlaceと接続）
- Scene Capture誘導（Quest 3で部屋未設定のとき）
- 受け入れ: 机の上にパネルを置ける。壁に板を貼れる

### S3: 環境メッシュ

- メッシュ取得、更新の流量制御、平面collision／周辺チャンクcollisionの二段構え
- オクルーダー材質の実機検証（第6節）
- 受け入れ: 仮想オブジェクトが実物の陰に隠れる。物理的に机の上で止まる

### S4: 深度オクルージョン

- 環境深度の取得とシェーダー経路、手の遮蔽
- 受け入れ: 手を仮想物体の前に出すと手が前に見える

### S5: アンカーと永続化

- アンカーの生成・保存・再読込
- 受け入れ: 壁に貼った板が、アプリ再起動後も同じ場所にある

## 9. リスクと未確定

| 項目 | 内容 | 対応 |
| --- | --- | --- |
| Compatibility rendererでの深度経路 | 深度テクスチャをシェーダーへ渡せるかが未確認 | S3のオクルーダー材質検証を先に単独で行い、駄目ならメッシュ遮蔽止まり |
| 端末の非対称性 | VIVEは空間認識ゼロ、PICOは未知数 | capability API前提。「無い」を正常系として設計 |
| 権限 | Meta: Scene API（`com.oculus.permission.USE_SCENE`）、Android XR: `android.permission.SCENE_UNDERSTANDING_COARSE`（dangerous）、カメラ: `horizonos.permission.HEADSET_CAMERA` | export presetと実行時要求の両方を手順化してREADMEへ |
| 部屋未スキャン | Quest 3でSpace Setup未実施なら結果は空 | `NEEDS_SETUP`を返し、Scene Captureへ誘導 |
| メッシュのコスト | collision生成とメモリ | 平面のみ既定、チャンク単位、フレーム分散 |
| 座標のずれ | recenterや再ローカライズで空間データが動く | `pose_recentered`で再取得。アンカー基準で配置する |
| coreのexperimental扱い | Spatial Entities関連クラスはexperimental | `ClassDB`越しの存在確認で包み、変更に備える |
| 実機確認の負荷 | 4機種 × 5段階 | S1・S2をQuest 3先行で作り、他機種は「壊れないこと」だけ先に確認 |

## 10. 決めたいこと

1. **端末の優先順位**: Quest 3を先行させ他は非対応として扱うか、最初から4機種で「取れないなりの動作」を揃えるか（提案は後者、ただし実装確認はQuest 3先行）
2. **環境メッシュの用途**: 物理（当たり判定）まで持たせるか、オクルージョンだけにするか
3. **セグメンテーションの範囲**: A＋Bで止めるか、C（カメラ画像＋ML）まで見込むか
4. **Android XRの扱い**: 実機が無いため未検証のまま設計に含めるか、コードだけ用意して検証は後回しにするか

## 参考

- [Godot 4.6 Release notes](https://godotengine.org/releases/4.6/)
- [Khronos: OpenXR Spatial Entities Extensions](https://www.khronos.org/blog/openxr-spatial-entities-extensions-released-for-developer-feedback)
- [Godot OpenXR Vendors plugin（GitHub）](https://github.com/GodotVR/godot_openxr_vendors)
- [Meta Scene Manager（Vendors docs）](https://godotvr.github.io/godot_openxr_vendors/manual/meta/scene_manager.html)
- [XR_ANDROID_trackables](https://developer.android.com/develop/xr/openxr/extensions/XR_ANDROID_trackables)
- [XR_ANDROID_scene_meshing](https://developer.android.com/develop/xr/openxr/extensions/XR_ANDROID_scene_meshing)
- [Understand permissions for XR（Android XR）](https://developer.android.com/develop/xr/permissions)
- [Develop with Godot for Android XR](https://developer.android.com/develop/xr/godot)
- [Passthrough Camera API overview（Meta）](https://developers.meta.com/horizon/documentation/spatial-sdk/spatial-sdk-pca-overview/)
