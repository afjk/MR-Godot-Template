# サンプル集としての構成 検討メモ

このリポジトリを「MRアプリを作るためのサンプル集」として育てるための構成案です。第8節のP1（骨格と基礎4サンプル）とP2（インタラクション6サンプル）は実装済みで、P3（空間認識）は平面検出・床面検知・深度系（リアルタイム推定とオクルージョン）まで進んでいます。

関連: [インタラクション基盤の検討](mr_toolkit_design.md) / [空間認識の検討](spatial_understanding_design.md)

## 1. 位置づけの変更

これまでは「最小のMRテンプレート1本」でした。サンプル集にすると、価値の置き所が変わります。

| | テンプレート | サンプル集 |
| --- | --- | --- |
| 価値 | そのまま使い始められること | **1つの機能の書き方が読んで分かること** |
| 良い設計 | 共通化・抽象化されている | 各サンプルが自己完結して短い |
| 抽象化 | 進めるほど良い | **進めすぎると読めなくなる** |
| 成功の指標 | 起動したら動く | 目的のサンプルがすぐ見つかり、コピーして使える |

この違いは、先に書いた2つの検討メモにも影響します。**MRTK相当のtoolkitを先に作るのは、サンプル集という目的には過剰**です。方針を次のように変更することを提案します。

> 共通コードは`shared/`に最小限だけ置く。**同じコードを3つのサンプルで書いたら、そのとき初めて`shared/`へ抽出する**（ボトムアップ）。toolkit（`addons/mrgt/`）は、サンプルが十分に溜まってから、抽出結果をまとめる形で作る。

## 2. リポジトリ構成案

```text
scenes/main.tscn          ランチャー。起動時のサンプル一覧（main_sceneはこれ）
scripts/launcher*.gd      ランチャーの実装（サンプルではないので規約の対象外）
shared/
  xr_rig.tscn             XROrigin3D、カメラ、左右のaim / gripコントローラー
  mr_stage.tscn / .gd     MRの土台。OpenXR初期化、blend mode、refresh rate、フォーカス処理
  sample_bootstrap.gd     Autoload。リグが無いシーンを単体実行したとき自動で挿す
  sample_info.gd          1サンプルの説明。ランチャーが一覧に使う
  sample_library.gd       一覧そのもの
samples/
  passthrough/            sample.tscn / sample.gd / README.md
  hand_tracking/
  controller_models/
  session_lifecycle/
  poke_button/
  ray_pointer/
  grab_object/
  ui_panel_2d/
  hand_menu/
  two_hand_manipulation/
  plane_detection/
  floor_detection/
  realtime_planes/
  occlusion_depth/
  samples.tres            一覧の定義（タイトル・説明・対応端末・シーンパス）
docs/                     ビルド手順、トラブルシューティング、検討メモ
export_presets.cfg        4機種分。APKは全サンプル入りの1本
```

> 実装時のメモ: 当初`xr_runtime.gd`と呼んでいたものは、環境・ライト・リグをまとめて持つため`mr_stage.gd`（`class_name MRStage`）にしました。共通UI（`shared/ui/`）は、まだ2サンプルでしか要らないため作っていません（第1節の「3つ書いてから抽出する」に従いました）。

### 3つの決めごと

**1. サンプルはリグを持たない。** 各`sample.tscn`はコンテンツだけを持ち、XRリグは`shared/xr_rig.tscn`が1箇所で面倒を見ます。リグ設定を全サンプルにコピーすると、設定を1つ直すたびに全サンプルを触ることになります。

**2. それでも単体で実行できる。** `sample_bootstrap.gd`（Autoload）が、シーン内に`XROrigin3D`が無ければ`xr_rig.tscn`を挿します。これで**エディタで`sample.tscn`を開いてF6を押せば、そのサンプルだけが動きます**。ランチャー経由と単体実行の両方が同じコードで動くことが、サンプル集では効きます。

**3. 一覧はデータで持つ。** `samples.tres`（`Resource`）にタイトル・説明・対応端末・シーンパスを書き、ランチャーはそれを読んでメニューを作ります。READMEの一覧表も同じ情報から書けます。サンプルを足すときに触るのは、自分のフォルダと`samples.tres`の1行だけです。

ディレクトリ名に連番（`01_`）は付けません。順序は`samples.tres`が持ちます。間に1つ足すたびに全部リネームするのは避けたいためです。

## 3. サンプルの書き方の規約

サンプル集の品質は、ほぼこの規約で決まります。

- **1サンプル1テーマ**。「パススルーとHand Trackingとボタン」は3つに分ける
- **1シーン1スクリプト**、目安200行以内。超えたらテーマが大きすぎる
- **依存は`shared/`のみ**。サンプル間で参照し合わない（コピーして持ち出せることを優先）
- スクリプト冒頭のコメントに、**何を示すサンプルか／必要なOpenXR extension・権限／対応端末**を書く
- **非対応端末では、理由をパネルに出して静かに終わる**。クラッシュも無反応も不可
- 各フォルダに`README.md`（数十行）。READMEは索引に徹し、詳細は各サンプルへ
- `gdformat` / `gdlint`を通す（既存CIの対象）

「非対応端末での見え方」を規約に入れるのは、この4機種構成では**サンプルの半分が特定端末でしか動かない**ためです。VIVE Focus Visionには空間認識のextensionがありません。何も起きないサンプルを見たユーザーが、自分の設定ミスを疑って時間を溶かすのを防ぎます。

## 4. サンプル一覧の案

現状のテンプレートは、この分類では最初の3つ分の内容を1シーンに詰めた状態です。まずこれを解きほぐすところから始まります。

### 基礎（既存コードの分割）

| サンプル | 内容 | 対応 |
| --- | --- | --- |
| `passthrough` | Alpha blendでのMR開始、非対応時のfallback | 全機種 |
| `hand_tracking` | `XRHandTracker`の26関節表示、光学式とコントローラー由来の区別 | 全機種 |
| `controller_models` | runtime提供のコントローラーモデル（core / Meta両対応） | 全機種 |
| `session_lifecycle` | refresh rate選択、フォーカス喪失、recenter | 全機種 |

### インタラクション

| サンプル | 内容 | 対応 |
| --- | --- | --- |
| `poke_button` | 指で押せるボタン。押し込み量・戻り・ハプティクス | 全機種 |
| `ray_pointer` | 遠隔レイ、カーソル、近接との切り替え | 全機種 |
| `grab_object` | pinch／グリップで掴んで動かす | 全機種 |
| `two_hand_manipulation` | 両手での回転・拡縮、制約 | 全機種 |
| `ui_panel_2d` | `SubViewport`の2D UIを3D面に出し、ポインタで操作 | 全機種 |
| `hand_menu` | 手のひらを向けると出るメニュー（solver） | 全機種 |

### 空間認識

| サンプル | 内容 | 対応 |
| --- | --- | --- |
| `plane_detection` | 検出された平面と意味ラベルの可視化（ARPlaneManager相当） | runtime次第 |
| `floor_detection` | 検出結果から床を選ぶ。取れなければLocal Floorの仮定 | 全機種（精度は端末差） |
| `scene_mesh` | 部屋メッシュの取得、collision、可視化 | Quest 3 / Android XR |
| `occlusion_mesh` | メッシュで実物が仮想物体を隠す（深度書き込み＋透明） | Quest 3 / Android XR |
| `realtime_planes` | 深度マップから見ている先の面をその場で推定 | Quest 3 |
| `occlusion_depth` | 環境深度による動的オクルージョン（手・人にも効く） | Quest 3 / Android XR |
| `spatial_anchor` | アンカーの生成・永続化・再読込 | Quest 3 / Android XR |
| `marker_tracking` | QRマーカーを基準に配置 | 端末次第 |

### 表現・性能

| サンプル | 内容 | 対応 |
| --- | --- | --- |
| `composition_layer` | 高解像度パネル（`OpenXRCompositionLayerQuad`） | 全機種 |
| `passthrough_style` | パススルーの色調整（Meta Color LUT等） | Quest 3 |
| `performance` | foveation、MSAA、負荷計測の見え方 | 全機種 |

オクルージョンを**2本に分けている**のが要点です。メッシュによる静的な遮蔽（`occlusion_mesh`）と、深度による動的な遮蔽（`occlusion_depth`）は、必要な端末機能も実装も別物で、前者だけでも「机の裏に物が隠れる」体験は作れます。詳細は[空間認識の検討メモ](spatial_understanding_design.md)の第6・7節にあります。

## 5. ランチャー

- 起動すると、正面に一覧パネルが出る（`samples.tres`から生成）
- 各項目には**対応端末バッジ**を出す
- サンプル中は「サンプル一覧へ戻る」パネルが出ており、いつでも戻れる
- 選択は、コントローラーのaim poseからのレイと`select`アクション、Hand Trackingでは視線＋pinch、デスクトップでは上下キーとEnter

> 実装時のメモ: 一覧は`SubViewport`の2D UIではなく、`Label3D`と`Area3D`による3Dノードで作りました。2D UIを3D面に出す仕組みは`ui_panel_2d`サンプルの主題なので、ランチャーがそれを先取りしないためです。汎用のポインタもまだ作らず、ランチャー専用の`scripts/launcher_pointer.gd`に閉じています。

ただし**ランチャーはサンプルではない**ので、`shared/`ではなく専用の場所に置き、規約（200行以内など）の対象外とします。

## 6. ビルドとCI

- **APKは1本**。全サンプルを含み、ランチャーから選ぶ。端末ごとのpresetは現状の4つを維持
- サンプル追加でexport設定が増える場合（新しい権限・extension）は、**そのサンプルのREADMEに必要な設定を明記**し、presetにも反映する
- 既存の`static-checks.yml`（gdformat / gdlint）はそのまま全サンプルに効く
- 既存の`build-apk.yml`（PRでのAPKビルド）もそのまま使える
- 将来サンプルが増えて起動が重くなったら、サンプル単位の遅延ロードを検討（`samples.tres`にパスしか持たない設計なら移行できる）

## 7. READMEの再編

現在のREADMEは646行で、大半がビルド手順（Godot・JDK・Android SDK・4機種のpreset・トラブルシューティング）です。サンプルが増えるとここに一覧が乗り切りません。

```text
README.md              何のリポジトリか、サンプル一覧表、クイックスタート
docs/build.md          現READMEのビルド手順一式（Quest / PICO / VIVE / Android XR）
docs/troubleshooting.md 現READMEのトラブルシューティング
samples/*/README.md    各サンプルの説明
docs/*_design.md       検討メモ
```

READMEの冒頭で「どのサンプルが何を示すか」が一覧できる状態を目標にします。ビルド手順は消さず`docs/build.md`へ移し、READMEから明示的にリンクします。

## 8. 進め方

### P1: 骨格を作る（既存機能の分割）※実装済み

- `shared/xr_rig.tscn`と`shared/mr_stage.gd`を旧`scripts/main.gd`から切り出す
- `sample_bootstrap.gd`、`samples.tres`、最小のランチャー
- 基礎4サンプルへ分割（機能追加はしない。**現状の挙動を保つ**）
- README再編
- 受け入れ: 4機種で現状と同じ見た目・挙動。各サンプルをF6で単体実行できる

ここは新機能ゼロで、既存の動作を壊していないことが確認しやすい段階です。最初にやるのが安全です。

### P2: インタラクション ※実装済み

- `poke_button` → `ray_pointer` → `grab_object` → `ui_panel_2d` の順
- 3つ目あたりで「共通化すべきもの」（interactor/interactableの原型）が見えてくるので、**そこで初めて`shared/interaction/`へ抽出**する

> 実装時のメモ: 3サンプル（`poke_button`・`ray_pointer`・`grab_object`）の時点では、重複はpinch判定2箇所だけだったので何も抽出しませんでした。`ui_panel_2d`と`hand_menu`を足した時点で**pinch判定が5箇所**（ランチャーを含む）になったため、規約どおり`MRStage.is_pinching()` / `is_pinch_just_started()`として共通化しました。閾値も1箇所にまとまり、機種ごとの調整がやりやすくなります。
>
> ポインタの出所（コントローラーのaim poseか視線か）も、実機で片手のトラッキングが外れると操作できなくなる不具合が出たため、同じく`MRStage`へ寄せました。3箇所に同じ判断があると、直し漏れがそのまま挙動の差になります。
>
> 一方、**`shared/interaction/`はまだ作っていません。** interactor/interactableの抽象が要るのは「複数のinteractableを登録して調停する」段階からで、5サンプルはいずれも対象が数個で、それぞれの当たり判定が主題そのものでした。近接と遠隔の調停は`ray_pointer`の中に最小の形で入っています。

### P3: 空間認識 ※深度系まで実装済み（残りは環境メッシュとアンカー）

- `plane_detection` → `floor_detection` → `scene_mesh` → `occlusion_mesh` → `occlusion_depth`
- 端末差が大きいので、非対応端末での見え方を毎回確認する

> 実装時のメモ: 最初の`floor_detection`は、Meta Scene APIと「指先でpinchした高さを床にする」手動設定の組み合わせでした。**手動設定は検知ではない**という指摘を受けて作り直しています。Godot 4.6 coreに`OpenXRPlaneTracker`（`XR_EXT_spatial_plane_tracking`）があり、これがAR Foundationの`ARPlaneManager`に当たるベンダー非依存の経路です。
>
> いまは検出そのものを見せる`plane_detection`と、そこから床を1つ選ぶ`floor_detection`に分けています。`project.godot`には`xr/openxr/extensions/spatial_entity/*`を追加しました。
>
> さらに実機確認で「これは事前スキャンのデータを読むタイプで、リアルタイム検出が欲しい」という指摘を受けました。**平面APIが返すデータの出所（事前スキャンか、その場の検出か）はruntime依存で、OpenXRの仕様は区別しません。** Quest 3ではSpace Setupの結果です。その場の検出が要る場合は環境深度から自分で作るしかないため、`realtime_planes`（深度マップから面を推定）と`occlusion_depth`（深度によるリアルタイム遮蔽）を追加しました。この2本はQuest 3限定です。
>
> 空間認識の層（`MRGTSpatialManager`相当）は、core・Meta・Android XRの経路が2つ以上そろい、正規化する意味が出てから作ります。

### P4: 表現・性能、toolkit化の判断

- サンプルが揃った段階で、`shared/`に溜まったものを`addons/mrgt/`として切り出すかを判断する

## 9. リポジトリを分けるか

**結論: 今は分けません。1リポジトリ・1Godotプロジェクトで進めます。**

分割案としては「テンプレート／サンプル集／toolkit」の3分割、あるいは「サンプルごとに独立したGodotプロジェクト」（`godot_openxr_vendors`の`samples/`方式）が考えられますが、今の状況ではコストが上回ります。

### 分けない理由

1. **重複するのがいちばん高いものが、ビルド周りだから**。4機種分のexport preset、646行のビルド手順、APKビルドCI、OpenXR Vendors pluginの導入手順。リポジトリを分けると、この一式が分割数だけ増えます。サンプルのコードより、こちらの維持コストのほうがずっと高くつきます。
2. **1つのAPKで全部試せることが、サンプル集の価値そのものだから**。実機に1回入れれば全サンプルを見られる状態は、リポジトリを分けると成立しません。
3. **toolkitはまだ存在しないから**。第1節のとおり共通コードはサンプルからの抽出で作ります。抽出物が無い段階で入れ物だけ用意しても、空のリポジトリが増えるだけです。

### 分けるべきタイミング（将来のトリガー）

次のいずれかに当たったら、そのときに切り出します。**先回りはしません。**

| トリガー | 切り出すもの | 理由 |
| --- | --- | --- |
| 共通コードが十分に育ち、他プロジェクトから使いたくなった | toolkit（`addons/mrgt/`） | AssetLibでの配布とバージョン付けには独立リポジトリが要る |
| プロジェクト設定が両立しないサンプルが出た（renderer、hybrid app、特殊なmanifest等） | そのサンプルだけ | 1つの`project.godot`で表現できないものは同居できない |
| GDExtension（ネイティブビルド）が必要になった | その領域だけ（例: カメラ画像＋ML推論） | ビルド環境とCIの性質が別物になる |

3つ目は現実的に起こり得ます。セグメンテーションのC層（[空間認識メモ](spatial_understanding_design.md)第7節）は、その時点で別リポジトリ行きです。

### 「最小構成から始めたい人」への対処

リポジトリを分けたくなる動機の多くは、実はこれです。同じリポジトリ内で解決します。

- `samples/minimal/`（パススルー＋リグだけ）を1本用意する
- READMEに「新規プロジェクトの始め方: `shared/`と好きなサンプル1つをコピーする」を明記する

サンプルが`shared/`にしか依存しない規約（第3節）を守っていれば、この持ち出しは実際に機能します。**規約が守れているかの検証にもなります。**

### リポジトリ名

サンプル集にするなら`MR-Godot-Template`から`MR-Godot-Samples`のような名前へ変更することを勧めます。GitHubは旧URLからリダイレクトするため、既存のリンクやcloneは壊れません。

## 10. 決めたいこと

1. **サンプルの単体実行**を規約に入れるか（`sample_bootstrap.gd`を作るか）。エディタでの反復が速くなる代わりに、Autoloadが1つ増えます
2. **README再編**を今やるか、サンプルが増えてからにするか
3. **P1の範囲**: 基礎4サンプルへの分割まで一気にやるか、まずランチャーと1サンプルだけ作って形を確認するか
4. **リポジトリ名・説明文**: 「Template」から「Samples」寄りに変えるか（GitHub上の名前とREADMEの1行目）
