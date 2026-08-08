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

## ビルド手順

以下は、開発用のDebug APKを作り、Quest 3へインストールするまでの手順です。GodotやAndroid開発が初めてでも、上から順番に進めればビルドできます。

### 1. リポジトリを取得

```bash
git clone https://github.com/afjk/Quest-MR-Godot-Template.git
cd Quest-MR-Godot-Template
```

### 2. Godot 4.6をインストール

[Godot Engine](https://godotengine.org/download/)からGodot 4.6系をインストールします。このプロジェクトでビルド確認済みのバージョンは `4.6.3-stable` です。

Godot本体と同じバージョンのExport Templatesも必要です。

1. Godotを起動します。
2. `Editor > Manage Export Templates` を開きます。macOSではメニュー名が `Godot > Manage Export Templates` の場合があります。
3. `Download and Install` を選択します。
4. インストール済みのtemplateバージョンがGodot本体と一致することを確認します。

Godot 4.6.3を使う場合は、Export Templatesも4.6.3にしてください。

### 3. OpenJDK 17をインストール

[Adoptium Temurin 17](https://adoptium.net/temurin/releases/?version=17)などからOpenJDK 17をインストールします。Godot 4.6ではJDK 17が推奨されています。

ターミナルで確認できます。

```bash
java -version
```

出力に `17` が含まれていれば使用できます。複数バージョンのJavaがある場合も、後述するGodotの `Java SDK Path` にはJDK 17の場所を指定してください。

### 4. Android SDKをインストール

[Android Studio](https://developer.android.com/studio)をインストールし、一度起動して初期セットアップを完了します。`SDK Manager` で次のパッケージを導入してください。

- Android SDK Platform-Tools 35.0.0以降
- Android SDK Build-Tools 35.0.1
- Android SDK Platform 35
- Android SDK Command-line Tools (latest)
- CMake 3.10.2.4988404
- NDK 28.1.13356709

コマンドライン版の`SDK Manager`を使う場合は次の構成です。

```bash
sdkmanager --sdk_root=<ANDROID_SDKのパス> \
  "platform-tools" \
  "build-tools;35.0.1" \
  "platforms;android-35" \
  "cmdline-tools;latest" \
  "cmake;3.10.2.4988404" \
  "ndk;28.1.13356709"
```

Android SDKの一般的な場所は次のとおりです。

- macOS: `/Users/<ユーザー名>/Library/Android/sdk`
- Windows: `%LOCALAPPDATA%\Android\Sdk`
- Linux: `$HOME/Android/Sdk`

### 5. GodotにJDKとAndroid SDKの場所を設定

1. Godotで `Editor Settings` を開きます。macOSでは `Godot > Editor Settings`、Windows/Linuxでは `Editor > Editor Settings` です。
2. 左側から `Export > Android` を開きます。
3. `Java SDK Path` にOpenJDK 17のディレクトリを指定します。
4. `Android SDK Path` にAndroid SDKのディレクトリを指定します。

`Android SDK Path`として指定するディレクトリの中に `platform-tools/adb` が存在する必要があります。

### 6. OpenXR Vendors pluginをインストール

QuestのパススルーとMeta固有のExport設定には公式のGodot OpenXR Vendors pluginを使います。大容量の配布バイナリなので、このリポジトリにはコミットしていません。

#### Godot AssetLibから入れる方法

1. Godotでこのプロジェクトを開きます。
2. エディター上部の `AssetLib` を開きます。
3. `Godot OpenXR Vendors` を検索します。
4. Godot 4.6に対応する版をインストールします。このプロジェクトで確認済みなのは `5.1.0-stable` です。

#### GitHub Releaseから入れる方法

1. [Godot OpenXR Vendors 5.1.0-stable](https://github.com/GodotVR/godot_openxr_vendors/releases/tag/5.1.0-stable)から `godotopenxrvendorsaddon.zip` を取得します。
2. ZIP内の `asset/addons/godotopenxrvendors` ディレクトリを、プロジェクトの `addons` の下へ展開します。

最終的に次のファイルが存在すれば配置は正しいです。

```text
addons/godotopenxrvendors/plugin.gdextension
```

配置後にGodotがpluginを認識しない場合は、プロジェクトを閉じて開き直してください。

### 7. Android Gradle Build Templateをインストール

プロジェクトをGodotで開き、`Project > Install Android Build Template...` を実行します。確認ダイアログではインストールを続行してください。

これによりプロジェクト直下に `android` ディレクトリが生成されます。このディレクトリはビルド時に再生成できるため、`.gitignore` の対象です。

### 8. Quest 3用Export設定を確認

`Project > Export` を開き、左側の `Meta Quest 3` presetを選択します。preset自体はリポジトリに含まれています。

次の値になっていることを確認してください。

- `Use Gradle Build`: 有効
- `Architectures > Arm 64 -v 8a`: 有効
- その他のArchitecture: 無効
- `XR Mode`: `OpenXR`
- `OpenXR Vendors > Meta`: 有効
- `Meta XR Features > Passthrough`: `Required`
- `Meta XR Features > Hand Tracking`: `Optional`
- `Meta XR Features > Hand Tracking Frequency`: `High`
- `Meta XR Features > Boundary Mode`: `Enabled`
- `Meta XR Features > Quest 3 Support`: 有効
- Quest 1、Quest 2、Quest Pro Support: 無効

Meta関連の項目が表示されない場合は、OpenXR Vendors pluginが正しい場所に入っていません。手順6を確認してください。

### 9. Godotの画面からAPKをビルド

1. `Project > Export` を開きます。
2. `Meta Quest 3` presetを選択します。
3. `Export Project` を押します。
4. `Export With Debug` を有効にします。
5. 出力先を `build/quest-mr-template.apk` にします。
6. `Save`または`Export`を押します。

成功すると次のAPKが作成されます。

```text
build/quest-mr-template.apk
```

初回ビルドではGradleが依存ファイルを取得するため、インターネット接続が必要です。

### 10. コマンドラインからAPKをビルド

GodotのGUIでJDKとAndroid SDKのパスを設定し、OpenXR Vendors pluginを配置した後は、コマンドラインでもビルドできます。

```bash
godot --headless --path . \
  --install-android-build-template \
  --export-debug "Meta Quest 3" \
  build/quest-mr-template.apk
```

macOSでGodotを `/Applications` に置いた場合の例です。

```bash
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

"$GODOT" --headless --path . \
  --install-android-build-template \
  --export-debug "Meta Quest 3" \
  build/quest-mr-template.apk
```

Android Build Templateをすでにインストール済みの場合は、`--install-android-build-template`を省略できます。

### 11. Quest 3を開発者モードにする

Quest 3へAPKを直接インストールするには、Metaの開発者組織を作成し、Quest 3のDeveloper Modeを有効にする必要があります。設定後、Quest 3をUSBケーブルでPCへ接続します。

ヘッドセット内にUSB debuggingの確認が表示されたら許可してください。`adb`から次のように見えれば接続できています。

```bash
adb devices
```

例:

```text
List of devices attached
1WMH0000000000  device
```

`unauthorized`と表示される場合は、ヘッドセットを装着してUSB debuggingを許可します。

### 12. APKをQuest 3へインストール

```bash
adb install -r build/quest-mr-template.apk
```

`Success`と表示されたらインストール完了です。Quest 3のアプリ一覧から提供元不明または開発中アプリの表示へ切り替え、`Quest MR Godot Template`を起動します。

GodotがQuest 3を認識している場合は、エディター右上のone-click deployからビルドと起動をまとめて行うこともできます。

署名が異なる古いAPKがインストール済みの場合、`INSTALL_FAILED_UPDATE_INCOMPATIBLE`になることがあります。その場合だけ、古いアプリを削除してから再インストールします。次のコマンドはアプリの保存データも削除します。

```bash
adb uninstall com.example.questmrgodottemplate
adb install build/quest-mr-template.apk
```

### 13. 正常動作の確認

起動後、次の状態になれば成功です。

- Quest 3のパススルー映像が背景に表示される
- 正面約1.5mにオレンジ色の回転キューブが表示される
- Touch Controllerを追跡中は左右の小さなマーカーが表示される
- Hand Tracking中は左右26関節が青と赤の球で表示される

光学式Hand Trackingを確認するときはQuest側のHand Trackingを有効にし、Touch Controllerを置いて、両手をヘッドセットのカメラから見える位置へ出してください。

## トラブルシューティング

### `No export template found`と表示される

Godot本体と同じバージョンのExport Templatesが必要です。手順2からインストールしてください。

### `Android build template not installed`と表示される

`Project > Install Android Build Template...` を実行してください。

### Meta XR FeaturesがExport画面に表示されない

`addons/godotopenxrvendors/plugin.gdextension` が存在するか確認し、Godotを開き直してください。

### JavaまたはGradleのエラーになる

Godotの `Java SDK Path` がJDK 17を指しているか確認してください。初回Gradle buildではインターネット接続も必要です。

### Quest 3が`adb devices`に出ない

- Developer Modeが有効か確認する
- データ通信対応のUSBケーブルを使う
- ヘッドセット内のUSB debugging確認を許可する
- WindowsではMeta Quest用ADB driverが必要になる場合がある

### パススルーが表示されない

- 実機のQuest 3で起動しているか確認する
- Export presetのMeta pluginとPassthroughが有効か確認する
- Quest側でアプリに必要な権限を許可する
- OpenXR Vendors pluginのバージョンがGodot 4.6に対応しているか確認する

### Hand Trackingの球が表示されない

- Quest側のHand Trackingを有効にする
- Touch Controllerを手から離す
- 明るい場所で、手をヘッドセット前面カメラから見える位置へ出す
- Export presetのHand Trackingが`Optional`または`Required`になっているか確認する

### `No project icon specified`という警告が出る

現時点ではプロジェクトアイコンを同梱していないため表示されます。Debug APKのビルド自体には影響しません。

AndroidとXR exportの詳細は [Exporting for Android](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) と [Deploying to Android](https://docs.godotengine.org/en/4.6/tutorials/xr/deploying_to_android.html) を参照してください。

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
