# MRTK相当のMRインタラクション基盤 検討メモ

このテンプレートの上に、MRTK3（Mixed Reality Toolkit for Unity）に相当するインタラクション基盤を作るための検討メモです。実装はまだ行っていません。方針・構造・段階の合意を取るための資料です。

- 対象: Godot 4.6 / Compatibility renderer / OpenXR / Quest 3・PICO 4 Ultra・VIVE Focus Vision・Android XR
- 立ち位置: 現テンプレート（起動・パススルー・Hand Tracking表示まで）の**次の層**
- 仮称: **MRGT (Mixed Reality Godot Toolkit)**、addon置き場は`addons/mrgt/`、`class_name`接頭辞は`MRGT`

## 1. 結論の要約

| 論点 | 提案 |
| --- | --- |
| 何を作るか | XRI相当の`Interactor` / `Interactable`抽象を自作し、その上にUX部品・空間操作・Solverを積む |
| 言語 | GDScript（テンプレートの導入障壁を上げない。C#はAndroid書き出しの前提が増える） |
| Godot XR Toolsとの関係 | **依存しない**。MITなので必要箇所のみ設計参考・部分移植 |
| 置き場所 | このリポジトリの`addons/mrgt/`。テンプレート本体（`scenes/main.tscn`）はaddon非依存のまま維持し、デモだけが依存する |
| 当たり判定 | Autoloadのレジストリ＋距離判定を主経路、物理（`Area3D`）は任意経路 |
| 最初に作るもの | デスクトップ手シミュレーター → near/far interactor → 押せるボタン |

「MRTKみたいなもの」を一度に作ることはできないので、**押せるボタンが1つ、実機3機種で同じ手触りで動く**ところを最初のゴールに置きます。

## 2. 背景

現テンプレートが持っているのは以下までです（詳細は[README](../README.md)）。

- OpenXR初期化、Alpha blendによるパススルー、デスクトップfallback
- refresh rate選択、フォーカス喪失時の停止、recenterの中継
- `XRHandTracker`の26関節の球表示、runtime提供のコントローラーモデル表示

つまり「**入力が取れて、見えている**」状態です。ここから先、アプリを書く人が毎回自前で書くことになるのが、MRTKが埋めていた領域です。

- 指で押せるボタン、掴んで動かせるオブジェクト、追従するメニュー
- 近接（poke/grab）と遠隔（ray）の切り替え、ホバー表現、ハプティクス
- 実機に焼かずに机の上で試す手段

## 3. MRTK3の棚卸しと採否

MRTK3のパッケージ構成を、Godotで作る場合の相当物に対応づけます。

| MRTK3パッケージ | 中身 | Godotでの相当 | 採否 |
| --- | --- | --- | --- |
| Core Definitions | 型・共通定義 | `addons/mrgt/core/` の基底クラスとenum | 採用（M1） |
| Input | XRI由来のinteractor群（poke / grab / ray / gaze）、Interaction Mode Manager、input simulation | 自作interactor群＋`MRGTInteractionManager`（Autoload）＋デスクトップシミュレーター | 採用（M0-M1） |
| UX Core | `StatefulInteractable`、`PressableButton`、状態→視覚のマッピング | `MRGTInteractable`、`MRGTPressableButton`、`MRGTStateVisualizer` | 採用（M2） |
| UX Components | ボタン・スライダー・ダイアログ・ハンドメニュー等のprefab群 | `addons/mrgt/ux/` のPackedScene群 | 部分採用（M2-M4） |
| Spatial Manipulation | `ObjectManipulator`、`BoundsControl`、constraints、Solvers | `MRGTObjectManipulator`、`MRGTBoundsControl`、`MRGTSolver*` | 採用（M3-M4） |
| Data Binding / Theming | データ束縛とテーマ | `Resource`ベースの`MRGTTheme`のみ。データ束縛は見送り | 縮小採用（M4） |
| Accessibility | 読み上げ・可読性支援 | なし | 見送り |
| Audio | HRTF spatializer | Godot標準の3Dオーディオ＋効果音フック | 最小限（M2） |
| Diagnostics | パフォーマンス可視化 | 簡易HUD（FPS・描画・interactor状態） | 任意（M4） |
| Graphics Tools | MRデザイン言語のシェーダー群 | Compatibility rendererで動く最小マテリアルのみ | 縮小採用 |
| Speech | 音声コマンド | Godot/OpenXRに標準経路がない | 見送り |

**見送りの理由**は共通で、「Godot側に土台がなく、単独で1プロジェクト分の規模になる」ものだからです。特にGraphics Tools相当（acrylic風の板、近接ライト、角丸ボーダー）は見栄えへの寄与が大きい反面、Compatibility rendererでの実装制約が強いので、**独立した検討**に回します。

## 4. Godot側の既存資産の棚卸し

作らずに済むものを先に確定させます。

### Godot 4.6 core

| 機能 | 使えるもの |
| --- | --- |
| リグ | `XROrigin3D` / `XRCamera3D` / `XRController3D` / `XRNode3D` |
| 手 | `XRHandTracker`（26関節・関節フラグ・半径）、`XRHandModifier3D`（Skeleton3Dへの適用） |
| コントローラーモデル | `OpenXRRenderModelManager`（本テンプレートで使用中） |
| 平面UI | `SubViewport` + `Control`、`OpenXRCompositionLayerQuad`系（experimental） |
| 空間認識 | Spatial Entities（anchor / plane / marker）。`OpenXRSpatialEntityTracker`、`OpenXRMarkerTracker`、`OpenXRSpatialAnchorCapability`（experimental） |
| 判定 | `Area3D` / `ShapeCast3D` / `RayCast3D` |

つまり**入力とアンカーはcoreで足りる**見込みです。MRGTが埋めるのは、その上の「意味づけ」（誰が何をホバーし、選択し、掴んでいるか）と、UX部品です。

### OpenXR Vendors plugin

パススルー、Meta系のrender model、scene（部屋メッシュ・平面）、hand mesh等を提供します。ただし**端末ごとに公開されるextensionが違う**ため、MRGTは直接依存せず、`ClassDB.class_exists()`で存在確認してから使う既存テンプレートの流儀（`scripts/main.gd`の`_setup_controller_render_models()`）を踏襲します。

### Godot XR Tools（MIT）

pointer、pickable、poke、hands、locomotionを提供する既存ライブラリで、4.6に対応し現在も更新されています。関係の選択肢は3つあります。

1. **依存する**: 実装量は最小。ただしVRゲーム前提（移動・掴み・climb中心）で、MRのUX部品（押し込みボタン、ハンドメニュー、bounds control、solver）は薄く、結局その上に層を重ねることになります。`XRTools*`とMRGTの二重の抽象が並ぶのは、テンプレートの読みやすさを損ないます。
2. **部分移植**: MITなので、`Viewport2Din3D`相当（3D空間上の2D UI、ポインタのマウス擬似入力）のように再実装コストが高く枯れている部分だけ、出典を明記して取り込みます。
3. **独立**: それ以外は自作。

**提案は2＋3**です。ただし「移動（locomotion）が欲しくなったらXR Toolsを併用する」余地は残します。MRGTのinteractorがXR Toolsの物理レイヤーと衝突しないよう、**物理レイヤーの使用番号を規約として文書化**します。

## 5. Godot流への読み替え

MRTKはUnityの語彙で書かれているので、そのまま移すと不自然になります。対応方針を先に決めます。

| MRTK / Unity | Godotでの表現 |
| --- | --- |
| Subsystem（HandsAggregator等） | Autoloadシングルトン1つ（`MRGTInteractionManager`）＋`Resource`の設定 |
| MonoBehaviour + interface | `class_name`付き基底Node＋signal。インターフェース代わりに`is_class` / duck typing は使わず基底継承で揃える |
| XRI Interactor/Interactable | 自作のNode。`XRController3D`や手の関節の子として配置 |
| UnityEvent | Godotのsignal（`hover_entered(interactor)`など） |
| Canvas（RectTransform）ベースの立体UI | 近接押下がある部品は3Dネイティブ、情報密度の高いパネルは`SubViewport`→3D面 |
| ScriptableObject（テーマ・設定） | `Resource`（`.tres`） |
| Prefab | `PackedScene`（`.tscn`） |
| Input Simulation | デスクトップfallback上のマウス／キーボード手シミュレーター |

## 6. アーキテクチャ案

### レイヤ

```text
L5  samples/         デモシーン（テンプレート本体はここにだけ依存）
L4  ux/              PressableButton, Slider, HandMenu, Panel, Dialog, Theme
L3  manipulation/    ObjectManipulator, BoundsControl, Constraints, Solvers
L2  interaction/     Interactable, InteractionManager(Autoload), 判定と排他
L1  input/           PokeInteractor, GrabInteractor, RayInteractor, 手・pinch抽象
L0  runtime/         XRリグ、セッション状態、blend mode、refresh rate、haptics
    ------------------------------------------------------------------
    Godot 4.6 core OpenXR  /  OpenXR Vendors plugin（存在すれば）
```

依存は**下向きのみ**とします。L4のボタンがL1のinteractorの型を知ることはなく、L2の`MRGTInteractable`のsignalだけを見ます。これはMRTK3が「状態と視覚を厳密に分離した」設計と同じ意図で、Canvas版と非Canvas版で同じ状態スクリプトを共有できるようにしたものです。

### ディレクトリ構成案

```text
addons/mrgt/
  plugin.cfg
  core/          共通enum、ユーティリティ、物理レイヤー定数
  runtime/       mrgt_xr_runtime.gd（現 main.gd から切り出す）、haptics
  input/         interactor群、hand_pose.gd（pinch判定など）、simulator/
  interaction/   interactable.gd、interaction_manager.gd、cursor
  manipulation/  object_manipulator.gd、bounds_control.gd、constraints/、solvers/
  ux/            button/、slider/、panel/、hand_menu/、theme/
  samples/       各機能の最小デモシーン
docs/
  mr_toolkit_design.md   このメモ
scenes/main.tscn         現状維持（MRGT非依存）
scenes/showcase.tscn     MRGTのデモ（新規、任意）
```

現在のCI（`.github/workflows/static-checks.yml`）は`:!:addons/**`でaddonをlint対象から外しています。これはOpenXR Vendorsを除外するための指定なので、**`addons/godotopenxrvendors/`のみ除外に変更**して、`addons/mrgt/`をgdformat/gdlintの対象に含めます。

### 主要APIのドラフト

```gdscript
# interaction/mrgt_interactable.gd
class_name MRGTInteractable
extends Node3D

signal hover_entered(interactor: MRGTInteractor)
signal hover_exited(interactor: MRGTInteractor)
signal selected(interactor: MRGTInteractor)
signal deselected(interactor: MRGTInteractor)
## 押し込み量やpinch量に相当する0.0-1.0の連続値。段階的な見た目に使う。
signal selectedness_changed(value: float)

## このinteractableを扱える経路。近接だけ、遠隔だけ、といった制限に使う。
@export_flags("Poke", "Grab", "Ray", "Gaze") var allowed_modes := 0b0111
@export var toggleable := false
```

```gdscript
# input/mrgt_interactor.gd
class_name MRGTInteractor
extends Node3D

enum Mode { POKE, GRAB, RAY, GAZE }

func get_mode() -> Mode:
	return Mode.POKE

## 0.0で非選択、1.0で完全選択。pinch量や押し込み量をそのまま返す。
func get_selectedness() -> float:
	return 0.0

## 判定形状。レジストリ側がこれを見て候補を絞る。
func get_interaction_origin() -> Vector3:
	return global_position
```

MRTK3の`StatefulInteractable`が持つ「選択の連続値（selectedness）」は、指の押し込みやpinchの度合いをそのまま見た目に流せるので、**この設計の中心**に置きます。ホバー時の縁取り、押し込み中の沈み込み、離した瞬間の戻りが、すべて同じ1つの値から作れます。

### 判定方式の選択

| 方式 | 内容 | 評価 |
| --- | --- | --- |
| A. レジストリ＋距離判定 | Autoloadが`MRGTInteractable`を登録し、interactorごとに毎フレーム距離／AABBで絞る | 物理に依存せず、フレーム同期のずれが出ない。数十個規模なら十分速い。**推奨** |
| B. `Area3D`の重なり | Godotの物理broadphaseに載せる | 数が増えても安定。ただし物理tickと描画tickの差でpoke感が鈍る場合がある |
| C. `ShapeCast3D` / `RayCast3D` | 遠隔レイに使う | 遠隔だけはCが自然。**Aと併用** |

**近接はA、遠隔はC**を主経路にし、Bは大量オブジェクト向けのオプションとして後から足せる形にします。本テンプレートは`Engine.physics_ticks_per_second`をディスプレイのrefresh rateへ合わせているので（`scripts/main.gd`の`_on_openxr_session_begun()`）Bの不利は小さいのですが、Aなら「手の姿勢を読んだそのフレームで判定する」ことが保証できます。

### near / far の排他

MRTKのInteraction Mode Managerに相当する調停を`MRGTInteractionManager`が行います。規則は次の通りです。

- 1つの`MRGTInteractable`を同時に選択できるinteractorは原則1つ（2手掴みは`MRGTObjectManipulator`が例外として扱う）
- 手がinteractableの近接圏に入ったら、その手のレイは自動的に無効化・非表示
- Hand TrackingとコントローラーはXRServer側で同時にactiveになり得るため、`scripts/main.gd`の`_is_hand_tracking_active()`と同じ判定で**どちらか一方の経路だけ**を有効にする

## 7. UIの実装方式

| 方式 | 向くもの | 懸念 |
| --- | --- | --- |
| 3Dネイティブ（MeshInstance3D + 自前レイアウト） | 押し込みボタン、スライダー、ハンドメニュー | テキスト描画とレイアウトを自前で持つ必要 |
| `SubViewport`上の`Control` → 3D面 | 設定画面、リスト、テキスト量の多いパネル | 解像度・可読性、`SubViewport`更新コスト |
| `OpenXRCompositionLayerQuad` | 静的で高解像度が要るパネル | experimental、パススルーとの合成順序、端末差 |

**提案**: 触覚に関わる部品（押し込み・掴み）は3Dネイティブ、テキスト主体のパネルは`SubViewport`。composition layerは「同じパネルの表示先を差し替えられる」形にしておき、後から実機で比較して決めます。

## 8. 段階的ロードマップ

各段階に受け入れ条件を置きます。実機は最低でもQuest 3で確認し、PICO 4 UltraとVIVE Focus Visionは段階の終わりにまとめて確認します。

### M0: 基盤整理（土台の掃除）

- `scripts/main.gd`を「XRセッション管理」と「デモ表示」に分割し、前者を`addons/mrgt/runtime/`へ
- XRリグを`PackedScene`化して再利用可能に
- **デスクトップ手シミュレーター**: マウスとキーで手の位置・pinchを模擬し、fallback表示上で判定を動かす
- 受け入れ: 実機ビルドなしで、PC上でホバー／選択が発生することを確認できる

シミュレーターを最初に置く理由は、以降の全段階の反復速度がここで決まるからです。APKを焼いて被って確認するループは1回数分かかります。

### M1: インタラクションのコア

- `MRGTInteractor`基底、poke（人差し指先端）、grab（pinch）、ray（遠隔）
- `MRGTInteractable`、`MRGTInteractionManager`、near/far排他
- カーソル／ホバー可視化、ハプティクス（`XRController3D.trigger_haptic_pulse()`）
- 受け入れ: 立方体に触れると色が変わり、pinchで掴んで動かせる。手とコントローラーの両方で動く

### M2: 最初のUX部品

- `MRGTPressableButton`（押し込み量・戻り・押し切り判定）、`MRGTStateVisualizer`
- パネル（`SubViewport`）と、ポインタからのマウス擬似入力
- 効果音とハプティクスのフック
- 受け入れ: ボタン3つのメニューを指で押せる。押し込みの手触りが3機種で同等

### M3: 空間操作

- `MRGTObjectManipulator`（片手／両手、移動・回転・拡縮）
- `MRGTBoundsControl`（枠とハンドル）
- constraints（軸固定、最小最大スケール、距離維持）
- 受け入れ: 両手でオブジェクトを回転・拡縮でき、制約が効く

### M4: Solverとテーマ

- `MRGTSolverHandler`＋Orbital / RadialView / Follow / HandConstraint（ハンドメニュー）/ SurfaceMagnetism / TapToPlace
- `MRGTTheme`（`Resource`）で色・寸法・効果音を一括変更
- ドキュメントとサンプルシーン
- 受け入れ: 手のひらを向けるとメニューが出る。テーマ差し替えで見た目が変わる

### M5: 空間認識との接続（拡張）

- Spatial Entitiesのanchor / planeを`MRGTInteractable`と接続（壁に貼る、机に置く）
- 受け入れ: 平面検出した机の上にパネルを置き、再起動後も同じ場所に出る

## 9. 品質と検証

- **静的チェック**: 既存のgdformat / gdlintを`addons/mrgt/`へ拡張（第6節）
- **単体テスト**: 判定・constraint・solverの数学部分はヘッドレスで検証可能。GUT等の導入を別途検討
- **実機マトリクス**: Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR。段階の終わりに全機種
- **性能予算**: Compatibility renderer・72〜90Hz前提。毎フレームの判定は「interactor数 × 候補interactable数」で見積もり、100 interactable規模までは距離判定で足りる想定。`SubViewport`は不可視時に更新停止する
- **手触りの基準**: 押し込みストローク、離す閾値（押し込みより浅い位置で離す＝ヒステリシス）、pinch閾値を`Resource`で一元管理し、機種ごとに微調整できるようにする

## 10. リスクと未確定事項

| 項目 | 内容 | 対応案 |
| --- | --- | --- |
| Compatibility rendererの制約 | 凝ったシェーダー・VRS・`SubViewport`負荷 | 見た目は単純なマテリアルから始め、Graphics Tools相当は別検討 |
| 手のモデル資産がない | スキン済みハンドメッシュを同梱していない | まず関節の球のまま進め、ライセンス的に配布可能なメッシュを別途調達 |
| Spatial Entitiesがexperimental | クラス名・APIが変わり得る | M5まで着手を遅らせ、`ClassDB`越しの存在確認で包む |
| Godotのバージョン追随 | 4.7以降でXR周りの追加・変更 | 4.6を基準に固定し、追随は別PRで扱う |
| テンプレートの「最小」思想との緊張 | MRGTを足すとテンプレートが重くなる | `addons/mrgt/`に閉じ込め、`scenes/main.tscn`は非依存を維持。将来別リポジトリへ切り出せる構造にする |
| 規模 | M1-M4はまとまった量になる | 段階ごとにPRを分け、各段階単体で使える状態にする |

## 11. 決めたいこと

1. **スコープ**: M1（コア）＋M2（ボタン）までを当面のゴールにするか、M3（掴み・bounds）まで見込むか
2. **置き場所**: このリポジトリの`addons/mrgt/`に置くか、最初から別リポジトリにしてテンプレートは薄いままにするか
3. **名前と接頭辞**: `MRGT`でよいか（`MRTK`は他プロダクト名なので避ける）
4. **Godot XR Tools**: 第4節の「部分移植＋独立」でよいか、それとも依存して上に載せるか
5. **最初の一歩**: 提案はM0のデスクトップ手シミュレーターです。実機確認のループを短くしてから中身に入りたいためですが、先に見栄えするもの（押せるボタン）を作る進め方でも構いません

## 参考

- [MRTK3 overview（Microsoft Learn）](https://learn.microsoft.com/en-us/windows/mixed-reality/mrtk-unity/mrtk3-overview/)
- [MixedRealityToolkit-Unity（GitHub）](https://github.com/MixedRealityToolkit/MixedRealityToolkit-Unity)
- [Godot XR Tools（GitHub / MIT）](https://github.com/GodotVR/godot-xr-tools)
- [Setting up XR（Godot 4.6）](https://docs.godotengine.org/en/4.6/tutorials/xr/setting_up_xr.html)
- [OpenXR hand tracking（Godot 4.6）](https://docs.godotengine.org/en/4.6/tutorials/xr/openxr_hand_tracking.html)
- [OpenXR composition layers（Godot 4.6）](https://docs.godotengine.org/en/4.6/tutorials/xr/openxr_composition_layers.html)
- [Godot 4.6 Release notes](https://godotengine.org/releases/4.6/)
