# Quest / PICO / VIVE / Android XR MR Godot Samples

Meta Quest 3、PICO 4 Ultra、VIVE Focus Vision、Android XR向けの、Mixed Reality（MR）サンプル集です。Godot 4.6、Compatibility renderer、OpenXRを前提にしています。

1つのAPKに全サンプルが入り、起動時のランチャーから選べます。各サンプルは1つの話題だけを扱い、`shared/`以外に依存しないので、フォルダごとコピーして自分のプロジェクトへ持ち出せます。

参考にしたUnity版は [Meta Quest MR Unity Template](https://github.com/afjk/Meta-Quest-MR-Unity-Template) です。

## サンプル一覧

| サンプル | 内容 | 対応端末 |
| --- | --- | --- |
| [パススルー](samples/passthrough/) | Alpha environment blendでMRを開始し、blend modeを切り替えて違いを見る | 全機種 |
| [Hand Tracking](samples/hand_tracking/) | `XRHandTracker`の26関節を表示し、光学式とコントローラー由来を見分ける | 全機種 |
| [コントローラーモデル](samples/controller_models/) | runtimeが提供するコントローラーの3Dモデル表示と、非対応時の球マーカー | 全機種 |
| [セッションの扱い](samples/session_lifecycle/) | リフレッシュレートの選択、フォーカスの喪失と復帰、recenter | 全機種 |
| [押せるボタン](samples/poke_button/) | 指先やコントローラーで押し込む。押し込み量から見た目と判定を作る | 全機種 |
| [遠隔ポインタ](samples/ray_pointer/) | レイで離れた対象を選ぶ。近づいたら近接へ切り替える | 全機種 |
| [掴んで動かす](samples/grab_object/) | pinch / gripで掴み、掴んだ瞬間の相対姿勢を手に掛け直す | 全機種 |

2D UIパネル、追従メニュー、両手操作、空間認識（床面検知、環境メッシュ、オクルージョン）は、[検討メモ](#今後の検討)の順で追加していきます。

## 共通の土台

すべてのサンプルが次を前提にしています。

- OpenXRの起動状態とAlpha environment blend対応を確認してMRを開始し、非対応ならデスクトップ表示にfallback
- `XROrigin3D`、`XRCamera3D`、左右のaim / gripコントローラー（[`shared/xr_rig.tscn`](shared/xr_rig.tscn)）
- runtimeが提供する最良のdisplay refresh rateを起動時に選び、物理レートを追従
- ヘッドセットを外したときの一時停止と、復帰での再開
- Local Floor reference spaceとfoveated rendering / MSAA 2xの推奨設定
- 実世界を覆う不透明な床や壁は置かない

これらは[`shared/mr_stage.gd`](shared/mr_stage.gd)にまとまっています。サンプル側はXRリグを持ちません。

## クイックスタート

```bash
git clone https://github.com/afjk/MR-Godot-Template.git
cd MR-Godot-Template
```

1. Godot 4.6系（確認済み: `4.6.3-stable`）とExport Templatesを入れる
2. OpenJDK 17とAndroid SDKを入れ、GodotのEditor Settingsでパスを設定する
3. OpenXR Vendors pluginを`addons/godotopenxrvendors/`へ入れる
4. `Project > Export`で端末のpresetを選び、APKを書き出す
5. `adb install`で実機へ入れる

各手順の詳細は[docs/build.md](docs/build.md)にあります。つまずいたら[docs/troubleshooting.md](docs/troubleshooting.md)を参照してください。

PCにOpenXR runtimeやHMDが無い場合、またはAlpha blendが使えない場合は、XR出力を有効にせず通常の3Dカメラで表示します。ランチャーは上下キーとEnterでも操作できます。

## リポジトリ構成

```text
scenes/main.tscn              ランチャー。起動時のサンプル一覧
scripts/launcher*.gd          ランチャーの実装（サンプルではない）
shared/xr_rig.tscn            XROrigin3D、カメラ、左右コントローラー
shared/mr_stage.tscn/.gd      MRの土台。OpenXR初期化、パススルー、セッション状態
shared/sample_bootstrap.gd    Autoload。リグの無いシーンを単体実行したとき土台を挿す
shared/sample_info.gd         1サンプルの説明。ランチャーが一覧に使う
samples/<name>/               sample.tscn / sample.gd / README.md
samples/samples.tres          サンプル一覧の定義
project.godot                 Godot 4.6 / Compatibility / OpenXR設定
export_presets.cfg            Quest / PICO / VIVE / Android XRのpreset
openxr_action_map.tres        aim / gripポーズと`select` / `grab` / `haptic`
docs/                         ビルド手順、トラブルシューティング、検討メモ
addons/godotopenxrvendors/    Meta/PICO/VIVE向けOpenXR Vendors plugin
```

## サンプルを追加する

1. `samples/<name>/`を作り、`sample.tscn`、`sample.gd`、`README.md`を置く
2. `samples/samples.tres`に1行足す（タイトル、説明、シーンパス、対応端末）

書き方の決めごとは次のとおりです。サンプル集は、読んで分かることが目的なので、共通化より自己完結を優先します。

- **1サンプル1テーマ**。1シーン1スクリプト、目安200行以内
- **依存は`shared/`のみ**。サンプル同士は参照し合わない
- スクリプト冒頭に、何を示すサンプルか・必要なextensionや権限・対応端末を書く
- **非対応端末では、理由を画面に出して静かに終わる**。クラッシュも無反応も避ける
- `gdformat`と`gdlint`を通す（CIで検査されます）

共通コードを増やすのは、**同じものを3つのサンプルで書いてから**です。方針の詳細は[docs/samples_plan.md](docs/samples_plan.md)にあります。

`samples/<name>/sample.tscn`をエディタで開いてF6を押すと、そのサンプルだけを実行できます。XRリグは`SampleBootstrap`が実行時に挿します。

## 今後の検討

- [docs/samples_plan.md](docs/samples_plan.md): サンプル集としての構成、サンプル一覧、進め方（一部は実装済み）
- [docs/mr_toolkit_design.md](docs/mr_toolkit_design.md): MRTK3相当のインタラクション基盤の設計案（共通化はサンプルからの抽出で行う方針です）
- [docs/spatial_understanding_design.md](docs/spatial_understanding_design.md): AR Foundation相当の空間認識（床面検知、環境メッシュ、セグメンテーション、アンカー）。未実装

## 既知の制約

- パススルー映像はMeta、PICO、またはVIVEのOpenXR runtimeが合成します。アプリからカメラ画像のピクセルやテクスチャ自体へはアクセスできません。
- 空間メッシュ、平面検出、anchorsは実装していません。
- Hand Trackingは関節データの取得とデバッグ表示のみです。スキニング済みハンドモデルやジェスチャー操作は含みません。
- MRにはOpenXR Vendors pluginと、対象端末専用のExport presetが必要です。Meta、PICO、Khronos loaderを同じpresetで同時に有効化しないでください。
- 実機の対応blend modeを実行時に確認し、Alpha blend非対応ならMRを開始しません。
- VIVEのpassthroughはOpenXR Vendors 5.1.0の`XR_HTC_passthrough` planar layerに限定されます。passthrough configurationとprojected passthroughは実装していません。
- OpenXR Vendors 5.1.0はHTC向けHand TrackingをAndroid manifest上でrequiredにするため、この構成ではHand Tracking非対応HTC端末への配布をOptional扱いにできません。

## 公式ドキュメント

- [Setting up XR](https://docs.godotengine.org/en/4.6/tutorials/xr/setting_up_xr.html)
- [OpenXR settings](https://docs.godotengine.org/en/4.6/tutorials/xr/openxr_settings.html)
- [AR / Passthrough](https://docs.godotengine.org/en/4.6/tutorials/xr/ar_passthrough.html)
- [OpenXR hand tracking](https://docs.godotengine.org/en/4.6/tutorials/xr/openxr_hand_tracking.html)
- [Godot OpenXR Vendors installation](https://godotvr.github.io/godot_openxr_vendors/getting-started/installation.html)
- [OpenXR PICO 4 controller profile](https://registry.khronos.org/OpenXR/specs/1.1/html/xrspec.html#_bytedance_pico_4_controller_profile)
- [OpenXR VIVE Focus 3 controller profile](https://registry.khronos.org/OpenXR/specs/1.1/man/html/XR_HTC_vive_focus3_controller_interaction.html)
- [VIVE OpenXR overview](https://developer.vive.com/resources/openxr/unity/overview/)
- [VIVE OpenXR Hand Tracking](https://developer.vive.com/resources/openxr/unity/tutorials/hand-tracking/hand-tracking-joint-pose/)
- [VIVE OpenXR Passthrough](https://developer.vive.com/resources/openxr/unity/tutorials/passthrough/)
