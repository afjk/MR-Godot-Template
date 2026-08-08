# Quest MR Godot Template

Meta Quest 3向けの最小Mixed Reality（MR）テンプレートです。Godot 4.6、Compatibility renderer、OpenXRを前提にしています。

外部アセット、Godot XR Tools、移動、掴み、UI、scene understanding、anchorsは含みません。参考にしたUnity版は [Meta Quest MR Unity Template](https://github.com/afjk/Meta-Quest-MR-Unity-Template) です。

## 含まれる機能

- OpenXRの起動状態とAlpha environment blend対応を確認してMRを開始
- Godot 4.3以降で推奨される `XRInterface.environment_blend_mode` APIでパススルーを要求
- `XROrigin3D`、`XRCamera3D`、左右の `XRController3D`
- Quest 3の光学式Hand Trackingとコントローラー推定Hand Tracking
- `XRHandTracker`が返す左右26関節の軽量な球表示
- 前方の回転キューブと、追跡中だけ表示する小さなコントローラーマーカー
- 実世界を覆う不透明な床なし
- OpenXR未初期化またはAlpha blend非対応時のデスクトップ表示fallback

## 必要環境

- [Godot Engine 4.6](https://godotengine.org/download/)
- Godot 4.6用Android export templates
- OpenJDK 17
- Android SDK（GodotのEditor SettingsでJava SDK PathとAndroid SDK Pathを設定）
- Meta Quest 3でDeveloper ModeとUSB debuggingを有効化
- OpenXR Vendors plugin `5.1.0-stable`（Godot 4.6以降対応）

Android環境の詳細は [Exporting for Android](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) を参照してください。

## OpenXR Vendors pluginの導入

APKビルドには公式プラグインを `addons/godotopenxrvendors` に配置します。このディレクトリは大容量の配布バイナリを含むため `.gitignore` の対象です。

初回セットアップまたは更新時は `AssetLib` か [Godot OpenXR Vendors releases](https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable) からGodot 4.6対応版を取得し、`addons/godotopenxrvendors` に配置してください。

## Quest 3向けExport設定

`export_presets.cfg` にはQuest 3向けのMeta設定を含めています。`Project > Export > Meta Quest 3` で次を確認できます。

- `XR Mode`: `OpenXR`
- `OpenXR Vendors`: `Meta Quest` を有効化
- `Meta Quest > Passthrough`: `Supported` または、常時MRに限定する場合は `Required`
- `Meta Quest > Hand Tracking`: `Optional`
- `Meta Quest > Hand Tracking Frequency`: `High`
- `Meta Quest > Quest 3 Support`: 有効
- Architecture: `arm64-v8a` のみ
- Gradle Build: 有効

AndroidへのXRデプロイは [Deploying to Android](https://docs.godotengine.org/en/4.6/tutorials/xr/deploying_to_android.html) も参照してください。

## 実機で実行

1. Godot 4.6の `Editor > Manage Export Templates` からAndroid templateを導入します。
2. Quest 3をUSB接続し、ヘッドセット内のUSB debugging確認を許可します。
3. 上記のExport設定を確認します。
4. Godot右上のone-click deploy、または `Project > Export` の `Export & Run` で実行します。
5. 初回起動時に必要なパススルー権限を許可します。

## デスクトップfallback

PCにOpenXR runtime/HMDがない場合、またはAlpha blendが使えない場合はXR出力を有効にせず、暗い背景上に同じキューブを通常の3Dカメラで表示します。`xr/openxr/startup_alert=false` により、OpenXR初期化失敗時もモーダル警告を出しません。

## 構成

```text
project.godot                 Godot 4.6 / Compatibility / OpenXR設定
export_presets.cfg            Android arm64 / OpenXRの最小preset
openxr_action_map.tres        左右コントローラーのdefault pose
scenes/main.tscn              XR rig、環境、最小デモ
scripts/main.gd               OpenXR、MR、fallback初期化
addons/godotopenxrvendors/    Meta Quest向けOpenXR Vendors plugin
```

## 既知の制約

- パススルー映像はMeta/OpenXR runtimeが合成します。アプリからカメラ画像のピクセルやテクスチャ自体へはアクセスできません。
- 空間メッシュ、平面検出、anchorsは実装していません。
- Hand Trackingは関節データの取得とデバッグ表示のみです。スキニング済みハンドモデルやジェスチャー操作は含みません。
- MRにはOpenXR Vendors pluginと、Export preset側のMeta Quest/Passthrough設定が必要です。
- 実機の対応blend modeを実行時に確認し、Alpha blend非対応ならMRを開始しません。

## 公式ドキュメント

- [Setting up XR](https://docs.godotengine.org/en/4.6/tutorials/xr/setting_up_xr.html)
- [OpenXR settings](https://docs.godotengine.org/en/4.6/tutorials/xr/openxr_settings.html)
- [AR / Passthrough](https://docs.godotengine.org/en/4.6/tutorials/xr/ar_passthrough.html)
- [OpenXR hand tracking](https://docs.godotengine.org/en/4.6/tutorials/xr/openxr_hand_tracking.html)
