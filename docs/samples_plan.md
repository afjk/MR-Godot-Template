# サンプル集としての構成 検討メモ

このリポジトリを「MRアプリを作るためのサンプル集」として育てるための構成案です。実装はまだ行っていません。

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
shared/
  xr_rig.tscn             XROrigin3D、カメラ、左右コントローラー、Hand Tracking
  xr_runtime.gd           OpenXR初期化、blend mode、refresh rate、フォーカス処理
  sample_bootstrap.gd     Autoload。リグが無いシーンを単体実行したとき自動で挿す
  ui/                     サンプル共通のパネル・ラベル（説明表示、非対応の告知）
samples/
  passthrough/            sample.tscn / sample.gd / README.md
  hand_tracking/
  controller_models/
  ...
  samples.tres            一覧の定義（タイトル・説明・対応端末・シーンパス）
docs/                     検討メモ
export_presets.cfg        4機種分。APKは全サンプル入りの1本
```

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
| `floor_detection` | 床面検知の3段構え（平面→メッシュ→Local Floor） | 全機種（精度は端末差） |
| `plane_detection` | 平面と意味ラベル、平面への配置 | Quest 3 / Android XR |
| `scene_mesh` | 部屋メッシュの取得、collision、可視化 | Quest 3 / Android XR |
| `occlusion_mesh` | メッシュで実物が仮想物体を隠す（深度書き込み＋透明） | Quest 3 / Android XR |
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
- 各項目には**対応端末バッジ**を出し、その端末で動かないものは理由付きでグレー表示
- サンプル中はいつでもランチャーへ戻れる（メニューボタン長押しなど）
- 一覧パネル自体が`ui_panel_2d`サンプルの実地デモになる

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

### P1: 骨格を作る（既存機能の分割）

- `shared/xr_rig.tscn`と`xr_runtime.gd`を`scripts/main.gd`から切り出す
- `sample_bootstrap.gd`、`samples.tres`、最小のランチャー
- 基礎4サンプルへ分割（機能追加はしない。**現状の挙動を保つ**）
- README再編
- 受け入れ: 4機種で現状と同じ見た目・挙動。各サンプルをF6で単体実行できる

ここは新機能ゼロで、既存の動作を壊していないことが確認しやすい段階です。最初にやるのが安全です。

### P2: インタラクション

- `poke_button` → `ray_pointer` → `grab_object` → `ui_panel_2d` の順
- 3つ目あたりで「共通化すべきもの」（interactor/interactableの原型）が見えてくるので、**そこで初めて`shared/interaction/`へ抽出**する

### P3: 空間認識

- `floor_detection` → `plane_detection` → `scene_mesh` → `occlusion_mesh` → `occlusion_depth`
- 端末差が大きいので、非対応端末での見え方を毎回確認する

### P4: 表現・性能、toolkit化の判断

- サンプルが揃った段階で、`shared/`に溜まったものを`addons/mrgt/`として切り出すかを判断する

## 9. 決めたいこと

1. **サンプルの単体実行**を規約に入れるか（`sample_bootstrap.gd`を作るか）。エディタでの反復が速くなる代わりに、Autoloadが1つ増えます
2. **README再編**を今やるか、サンプルが増えてからにするか
3. **P1の範囲**: 基礎4サンプルへの分割まで一気にやるか、まずランチャーと1サンプルだけ作って形を確認するか
4. **リポジトリ名・説明文**: 「Template」から「Samples」寄りに変えるか（GitHub上の名前とREADMEの1行目）
