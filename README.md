# Quest / PICO / VIVE / Android XR MR Godot Template

Meta Quest 3、PICO 4 Ultra、VIVE Focus Vision、Android XR向けの最小Mixed Reality（MR）テンプレートです。Godot 4.6、Compatibility renderer、OpenXRを前提にしています。

外部アセット、Godot XR Tools、移動、掴み、UI、scene understanding、anchorsは含みません。参考にしたUnity版は [Meta Quest MR Unity Template](https://github.com/afjk/Meta-Quest-MR-Unity-Template) です。

## 含まれる機能

- OpenXRの起動状態とAlpha environment blend対応を確認してMRを開始
- Godot 4.3以降で推奨される `XRInterface.environment_blend_mode` APIでパススルーを要求
- `XROrigin3D`、`XRCamera3D`、左右の `XRController3D`
- Quest 3、PICO 4 Ultra、VIVE Focus Visionの光学式Hand Tracking、およびruntimeが提供するコントローラー推定Hand Tracking
- `XRHandTracker`が返す左右26関節の軽量な球表示
- runtimeが提供するコントローラー3Dモデルの表示と、非対応時の球マーカーへのfallback
- 前方の回転キューブと、追跡中だけ表示する小さなコントローラーマーカー
- 実世界を覆う不透明な床なし
- runtimeが提供する最良のdisplay refresh rateを起動時に選択し、物理レートを追従
- ヘッドセットを外した際のフォーカス喪失で処理を一時停止し、復帰で再開
- Local Floor reference spaceとfoveated rendering / MSAA 2xの推奨設定
- OpenXR未初期化またはAlpha blend非対応時のデスクトップ表示fallback

## ビルド手順

以下は、開発用のDebug APKを作り、Quest 3、PICO 4 Ultra、またはVIVE Focus Visionへインストールするまでの共通手順です。GodotやAndroid開発が初めてでも、上から順番に進めればビルドできます。

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

Quest、PICO、VIVEのAndroid OpenXR loader、パススルー、ベンダー固有のExport設定には公式のGodot OpenXR Vendors pluginを使います。大容量の配布バイナリなので、このリポジトリにはコミットしていません。

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
- `Meta XR Features > Render Model`: `Optional`
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

## PICO 4 Ultra向けビルド

GodotとAndroid SDKの導入、OpenXR Vendors plugin、Android Gradle Build Templateまでは上記の手順2から7と共通です。同じプロジェクトを使用しますが、Godot OpenXR Vendorsの仕様に従い、MetaとPICOを同じExport presetでは同時に有効化していません。

### 1. PICO 4 UltraのOSを更新

ヘッドセットのシステムアップデートを実行し、利用可能な最新のPICO OSへ更新してください。PICO公式資料ではHand Trackingはシステムバージョン`5.11.0`以降、PICO 4 UltraのVideo See-Throughは`5.14.0`以降が要件です。

- [PICO Hand Tracking](https://developer.picoxr.com/home-api/document/unity/hand-tracking/)
- [PICO Video See-Through](https://developer.picoxr.com/en/document/unity/seethrough/)

### 2. PICO用Export設定を確認

`Project > Export`を開き、`PICO 4 Ultra` presetを選択します。次の値になっていることを確認してください。

- `Use Gradle Build`: 有効
- `Architectures > Arm 64 -v 8a`: 有効
- その他のArchitecture: 無効
- `XR Mode`: `OpenXR`
- `OpenXR Vendors > Meta`: 無効
- `OpenXR Vendors > PICO`: 有効
- `PICO XR Features > Hand Tracking`: `Optional`
- `PICO XR Features > Face Tracking`: `None`

このプロジェクトは標準OpenXRのAlpha environment blendと`XR_EXT_hand_tracking`を使用します。`project.godot`に残っている`xr/openxr/extensions/meta/passthrough`という設定名は、OpenXR Vendors pluginがPICOでも利用する`XR_FB_passthrough` fallbackを有効にするために必要です。PICO runtimeがネイティブAlpha blendを提供する場合はruntime側が優先されます。

### 3. PICO用APKをビルド

GodotのExport画面で`PICO 4 Ultra`を選び、`Export Project`からDebug APKを出力します。コマンドラインでは次のようにビルドできます。

```bash
godot --headless --path . \
  --install-android-build-template \
  --export-debug "PICO 4 Ultra" \
  build/pico4-ultra-mr-template.apk
```

Android Build Templateをすでにインストール済みの場合は、`--install-android-build-template`を省略できます。成功すると`build/pico4-ultra-mr-template.apk`が作成されます。

### 4. Developer ModeとUSB debuggingを有効化

PICO 4 Ultra側でDeveloper ModeとUSB debuggingを有効にし、データ通信対応のUSBケーブルでPCへ接続します。ヘッドセット内にUSB debuggingの許可が表示されたら承認してください。

```bash
adb devices
```

端末の状態が`device`なら接続済みです。`unauthorized`の場合は、ヘッドセット内の確認ダイアログを承認します。

### 5. PICO 4 Ultraへインストール

```bash
adb install -r build/pico4-ultra-mr-template.apk
```

署名が異なる古いDebug APKとの競合で`INSTALL_FAILED_UPDATE_INCOMPATIBLE`になる場合だけ、保存データが消えることを確認したうえで削除して入れ直します。

```bash
adb uninstall com.example.pico4ultramrgodottemplate
adb install build/pico4-ultra-mr-template.apk
```

起動後はパススルー背景、正面の回転キューブ、左右コントローラーマーカー、Hand Tracking時の左右26関節を確認してください。コントローラー姿勢にはOpenXR 1.1の`/interaction_profiles/bytedance/pico4_controller`を使用します。

## VIVE Focus Vision向けビルド

GodotとAndroid SDKの導入、OpenXR Vendors plugin、Android Gradle Build Templateまでは共通手順2から7と同じです。VIVE用presetではMeta/PICO pluginを無効にし、Godot OpenXR VendorsのKhronos Android OpenXR loaderをHTC modeで使用します。

### 1. VIVE Focus VisionのROMを更新

ヘッドセットのシステムとファームウェアを更新してください。VIVE OpenXR Plugin 2.5.1の公式互換表では、Focus Visionの推奨ROMは`7.0.999.308`です。これより新しい正式版が利用できる場合は最新の正式版を使用してください。

- [VIVE OpenXR overview and recommended versions](https://developer.vive.com/resources/openxr/unity/overview/)

### 2. VIVE用Export設定を確認

`Project > Export`を開き、`VIVE Focus Vision` presetを選択します。次の値になっていることを確認してください。

- `Use Gradle Build`: 有効
- `Architectures > Arm 64 -v 8a`: 有効
- その他のArchitecture: 無効
- `XR Mode`: `OpenXR`
- `OpenXR Vendors > Meta`: 無効
- `OpenXR Vendors > PICO`: 無効
- `OpenXR Vendors > Khronos`: 有効
- `Khronos XR Features > Vendors`: `HTC`
- `Khronos XR Features > HTC > Tracker`: `No`
- `Khronos XR Features > HTC > Lip Expression`: `No`

Godot OpenXR Vendors 5.1.0にはHTC用の独立したHand Tracking export選択肢がありません。`xr/openxr/extensions/hand_tracking=true`により標準`XR_EXT_hand_tracking`を要求し、既存の左右26関節処理を共用します。extensionを提供しないruntimeでもアプリの処理自体はfallbackできますが、同pluginはHTC presetのAndroid manifestへ`wave.feature.handtracking`を`required=true`で追加します。そのため、このバージョンでは配布manifest上のHand TrackingをOptionalにはできません。

### 3. VIVE用APKをビルド

GodotのExport画面で`VIVE Focus Vision`を選び、`Export Project`からDebug APKを出力します。コマンドラインでは次のようにビルドできます。

```bash
godot --headless --path . \
  --install-android-build-template \
  --export-debug "VIVE Focus Vision" \
  build/vive-focus-vision-mr-template.apk
```

Android Build Templateをすでにインストール済みの場合は、`--install-android-build-template`を省略できます。

### 4. Developer ModeとUSB debuggingを有効化

VIVE Focus系の公式手順では、`Settings > More Settings > Build Version`を7回選択してDeveloper Modeを有効にし、`Developer Options > USB Debugging`を有効にします。Focus VisionのROMによって項目名や場所が異なる場合があります。

- [VIVE Focus developer mode](https://developer.vive.com/resources/hardware-guides/vive-focus-specs-user-guide/how-do-i-put-focus-developer-mode/)

データ通信対応のUSBケーブルでPCへ接続し、ヘッドセット内のUSB debugging確認を許可します。

```bash
adb devices
```

端末の状態が`device`なら接続済みです。`unauthorized`の場合は、ヘッドセット内の確認ダイアログを承認します。

### 5. VIVE Focus Visionへインストール

```bash
adb install -r build/vive-focus-vision-mr-template.apk
```

署名が異なるAPKとの競合で`INSTALL_FAILED_UPDATE_INCOMPATIBLE`になる場合だけ、保存データが消えることを確認したうえで削除して入れ直します。

```bash
adb uninstall com.example.vivefocusvisionmrgodottemplate
adb install build/vive-focus-vision-mr-template.apk
```

### 6. Controller、Hand Tracking、passthrough

- ControllerはOpenXR 1.1の`/interaction_profiles/htc/vive_focus3_controller`を使用します。左右の`aim` poseを既存マーカーに使用し、左右の`grip` poseもaction mapへ登録しています。
- Hand Trackingは標準`XR_EXT_hand_tracking`の左右26関節を使用します。VIVE公式資料ではFocus VisionのAIOで対応しています。
- Passthroughは`xr/openxr/extensions/htc/passthrough=true`でOpenXR Vendors 5.1.0の`XR_HTC_passthrough` wrapperを有効にします。このwrapperはplanar passthrough composition layerをprojection layerの背面へ追加し、GodotのAlpha environment blendとして公開します。既存の`XRInterface.environment_blend_mode`処理をそのまま共用でき、独自GDExtensionは不要です。
- このHTC wrapperが提供するのはplanar passthroughの開始/停止相当です。passthrough configuration、projected passthrough、カメラ画像へのアクセスはこのテンプレートに含みません。

VIVE Focus Vision実機では、起動、Head/Controller tracking、aim/grip pose、光学式Hand Trackingの26関節、controllerからhandへの切り替え、Alpha blendによるpassthrough、アプリ再開後の復帰を確認してください。このブランチでは実機検証を行っていません。

## Android XR向けビルド

Samsung Galaxy XRなどのAndroid XR端末向けpresetです。GodotとAndroid SDKの導入、OpenXR Vendors plugin、Android Gradle Build Templateまでは共通手順2から7と同じです。

### 1. Android XR用Export設定を確認

`Project > Export`を開き、`Android XR` presetを選択します。次の値になっていることを確認してください。

- `Use Gradle Build`: 有効
- `Architectures > Arm 64 -v 8a`: 有効
- その他のArchitecture: 無効
- `XR Mode`: `OpenXR`
- `OpenXR Vendors > Meta`: 無効
- `OpenXR Vendors > PICO`: 無効
- `OpenXR Vendors > Khronos`: 無効
- `OpenXR Vendors > Android XR`: 有効
- `Android XR Features > Hand Tracking`: `Optional`
- `Android XR Features > Tracked Controllers`: `Optional`
- `Android XR Features > Recommended Boundary Type`: `None`
- `Android XR Features > Use Experimental Features`: 無効

### 2. パススルーに追加設定が不要な理由

Meta、PICO、VIVEと違い、**Android XRのパススルーにはベンダー固有の拡張設定が要りません**。Godot OpenXR Vendors 5.1.0のAndroid XR export pluginには`meta_xr_features/passthrough`や`xr/openxr/extensions/htc/passthrough`に相当する項目が存在せず、Android XRのMRは標準OpenXRのAlpha environment blendそのもので動作します。

このテンプレートの`scripts/main.gd`は`get_supported_environment_blend_modes()`でベンダー非依存に対応blend modeを判定しているため、Android XR向けにコードを変更する必要はありません。

### 3. Android XR用APKをビルド

```bash
godot --headless --path . \
  --install-android-build-template \
  --export-debug "Android XR" \
  build/android-xr-mr-template.apk
```

Android Build Templateをすでにインストール済みの場合は、`--install-android-build-template`を省略できます。

### 4. インストール

端末側でDeveloper ModeとUSB debuggingを有効にし、`adb devices`で`device`と表示されることを確認してからインストールします。

```bash
adb install -r build/android-xr-mr-template.apk
```

署名が異なるAPKとの競合で`INSTALL_FAILED_UPDATE_INCOMPATIBLE`になる場合だけ、保存データが消えることを確認したうえで削除して入れ直します。

```bash
adb uninstall com.example.androidxrmrgodottemplate
adb install build/android-xr-mr-template.apk
```

> **未検証**: このpresetはAndroid XR実機で動作確認していません。Export設定はGodot OpenXR Vendorsの`demo/export_presets.cfg`のAndroid XR presetに合わせています。

## コントローラーの3Dモデル表示

`scenes/main.tscn`の左右grip controller配下に、Godot 4.6 coreの`OpenXRRenderModelManager`を配置しています。`xr/openxr/extensions/render_model=true`と組み合わせて、runtimeが提供するコントローラーの実物3Dモデルを表示します。

コントローラーモデルを提供するOpenXR extensionは2種類あり、**どちらを公開するかはruntimeによって異なります**。

| extension | 実装元 | 確認済みの端末 |
| --- | --- | --- |
| `XR_EXT_render_model` | Godot 4.6 core | PICO 4 Ultra |
| `XR_FB_render_model` | OpenXR Vendors plugin | Meta Quest 3 |

そのため`scripts/main.gd`の`_setup_controller_render_models()`は起動時に**両方を用意し**、`_update_render_models()`が実際にモデルを返した方を毎フレーム採用します。どちらも返さない場合だけ、従来どおり左右で色分けした球マーカーを表示します。両方がモデルを返した場合はcore側を優先し、二重描画しません。

Meta経路の`OpenXRFbRenderModel`は`ClassDB.instantiate()`でclass名から生成しているため、OpenXR Vendors pluginが未インストールでもプロジェクトは読み込めます。

どのextensionが使えたかは起動時のログに出ます。

```text
OpenXR: render models - core true, Meta true
OpenXR: no render model extension available, using marker spheres
```

Meta経路を使うには次の2つが必要です。どちらか一方でも欠けるとQuestでモデルが表示されません。

- `project.godot`の`xr/openxr/extensions/meta/render_model=true`
- Quest presetの`Meta XR Features > Render Model`（`Optional`以上）

後者を有効にすると、Android manifestへ`com.oculus.permission.RENDER_MODEL`が追加されます。

あわせて`OpenXRInterface.set_motion_range()`を切り替えています。コントローラー由来のHand Trackingでは`CONFORM_TO_CONTROLLER`、光学式では`UNOBSTRUCTED`を指定し、指がコントローラーを突き抜けないようにします。

実際にモデルが出るかはruntimeが該当extensionを公開しているかに依存します。非対応でも球マーカーへ落ちるだけで、従来の挙動から後退はしません。

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

### PICO 4 UltraでパススルーまたはHand Trackingが動かない

- PICO OSを最新へ更新する
- `PICO 4 Ultra` presetでPICO pluginだけが有効か確認する
- PICO本体のHand Trackingを有効にし、コントローラーを置く
- アプリ起動時に表示される権限を許可する
- OpenXR Vendors pluginが`5.1.0-stable`であることを確認する

### VIVE Focus Visionで起動、パススルー、またはHand Trackingが動かない

- Focus VisionのROMを更新する
- `VIVE Focus Vision` presetでKhronos pluginだけが有効で、Vendorが`HTC`になっているか確認する
- OpenXR Vendors pluginが`5.1.0-stable`であることを確認する
- VIVE本体のHand Trackingを有効にし、アプリに必要な権限を許可する
- `adb logcat`でOpenXR runtimeまたはextension初期化エラーを確認する
- passthroughが使えない場合はruntimeが`XR_HTC_passthrough`を公開しているか実機で確認する

### OpenXRの挙動そのものを詳しく調べたい（Validation Layers）

Godot OpenXR Vendors 5.0以降には、Khronosの[OpenXR Validation Layers](https://www.khronos.org/blog/new-openxr-validation-layer-helps-developers-build-robustly-portable-xr-applications)がAndroidライブラリとして同梱されています。GodotのOpenXR呼び出しが仕様どおりかを実機で検証でき、テンプレートを改造して動かなくなったときの切り分けに使えます。

各presetには`xr_features/enable_openxr_validation_layers=false`を明示してあります。有効化する手順です。

1. `Project > Export`で対象のpresetを選びます。
2. `XR Features > Enable Openxr Validation Layers` を有効にします。
3. Debug APKをビルドして端末へインストールします。
4. `adb logcat`でvalidation messageを確認します。

`project.godot`には`xr/openxr/extensions/debug_utils=2`（Warning以上）を設定済みです。この設定が無いと、validation layerが検出した内容がGodot側のログに出ません。

APKサイズが増えるため、**Debugビルドでの一時的な調査にのみ使用し、配布ビルドでは無効に戻してください**。

### `No project icon specified`という警告が出る

現時点ではプロジェクトアイコンを同梱していないため表示されます。Debug APKのビルド自体には影響しません。

AndroidとXR exportの詳細は [Exporting for Android](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) と [Deploying to Android](https://docs.godotengine.org/en/4.6/tutorials/xr/deploying_to_android.html) を参照してください。

## GitHub ActionsでPRのAPKをビルド

`main`向けのPull Requestを作成または更新すると、[`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml) がQuest 3、PICO 4 Ultra、VIVE Focus Vision、Android XR用のDebug APKをmatrixで並列ビルドします。Unity参考リポジトリと同様に、ビルド結果はGitHub Actionsのartifactとして個別に保存されます。

CIでは次の環境を毎回再現します。

- Godot `4.6.3-stable`
- OpenJDK 17
- Android SDK Platform 35 / Build-Tools 35.0.1
- Godot Android Export Templates 4.6.3
- OpenXR Vendors plugin `5.1.0-stable`
- `Meta Quest 3`、`PICO 4 Ultra`、`VIVE Focus Vision`、`Android XR`のDebug export preset

PRのAPKを取得する手順です。

1. GitHubで `main` 向けのPull Requestを作成します。
2. PRのChecksまたはActionsタブで、`Meta Quest 3`、`PICO 4 Ultra`、`VIVE Focus Vision`、`Android XR`のDebug APK build完了を待ちます。
3. 完了したworkflow runを開きます。
4. ページ下部の`Artifacts`から必要なartifactをダウンロードします。
5. Quest用は`quest-mr-template-pr-<PR番号>`、PICO用は`pico4-ultra-mr-template-pr-<PR番号>`、VIVE用は`vive-focus-vision-mr-template-pr-<PR番号>`、Android XR用は`android-xr-mr-template-pr-<PR番号>`です。

artifactの保存期間は14日です。PRへ新しいcommitをpushすると古い実行はキャンセルされ、最新commitで再ビルドされます。Actions画面の `Run workflow` から手動実行することもできます。

このworkflowはDebug APK専用です。署名用Secretsを使用しないため、Meta Horizon Storeへ提出するRelease APK/AABは生成しません。

## GitHub ActionsでのGDScript静的チェック

[`.github/workflows/static-checks.yml`](.github/workflows/static-checks.yml) が、PRと`main`へのpushで[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit)を実行します。Godot OpenXR Vendorsリポジトリの`static_checks.yml`と同じ構成です。

- `gdformat --diff`: GDScriptの書式が整形結果と一致するか検証します
- `gdlint`: 命名規則や宣言順などのスタイル違反を検出します

対象はgitで追跡している`.gd`ファイルのうち`addons/`以外です。OpenXR Vendors pluginはビルド時に取得する外部アセットなので除外しています。

ローカルで同じチェックを実行する手順です。

```bash
pip install 'gdtoolkit==4.*'
gdformat --diff scripts/
gdlint scripts/
```

`gdformat --diff` が差分を出した場合は、`gdformat scripts/` で自動整形できます。

## パフォーマンス関連のプロジェクト設定

`project.godot` には、Godot OpenXR Vendors 5.0以降に同梱されるXR project setup wizardが推奨する値を設定しています。

```text
rendering/anti_aliasing/quality/msaa_3d=1   MSAA 2x
rendering/vrs/mode=2                        VRSをXRモードに
xr/openxr/reference_space=2                 Local Floor
xr/openxr/foveation_level=3                 Foveated renderingをHighに
xr/openxr/foveation_dynamic=true            負荷に応じてfoveationを変動
```

`rendering/vrs/mode`はForward+とMobileでのみ効きます。このテンプレートが使うCompatibility rendererにはrendering deviceが無いため、実際には`xr/openxr/foveation_level`の側がGPU負荷を下げます。`scripts/main.gd`の`_configure_foveation()`が実行時に判定し、rendering deviceがあれば`Viewport.VRS_XR`を設定し、無い場合はfoveation levelが未設定なら警告を出します。

`reference_space`をLocal Floorにしているため、原点は起動時のユーザー位置を基準にした床面になります。Stageと違いガーディアン設定に依存しないので、正面約1.5mのキューブがどこで起動しても同じ位置に出ます。

Godotエディター上では、OpenXR Vendors pluginが追加する`Project > Tools > XR Project Setup Wizard...`からも同じ推奨値を検証・適用できます。Export presetの必須項目も併せて検証されるため、手順8以降のpreset確認の補助として使えます。

## リフレッシュレートとフォーカス処理

`scripts/main.gd`は、OpenXRのセッションシグナルを受けて次の処理を行います。

- `session_begun`: `get_available_display_refresh_rates()`から`maximum_refresh_rate`（既定90Hz）以下で最良のレートを選び、`set_display_refresh_rate()`で適用したうえで`Engine.physics_ticks_per_second`を実測レートへ合わせます。runtimeがレートを返さない場合は`project.godot`の90Hzのままです。
- `session_visible` / `session_focussed`: ヘッドセットを外すなどでフォーカスを失うと`process_mode`を`PROCESS_MODE_DISABLED`にして処理を止め、復帰時に再開します。`focus_lost`と`focus_gained`シグナルも公開しています。
- `pose_recentered`: runtimeによるリセンターを`pose_recentered`シグナルとして中継します。実際の再配置内容はアプリ依存のため、このテンプレートでは何も動かしません。

## デスクトップfallback

PCにOpenXR runtime/HMDがない場合、またはAlpha blendが使えない場合はXR出力を有効にせず、暗い背景上に同じキューブを通常の3Dカメラで表示します。`xr/openxr/startup_alert=false` により、OpenXR初期化失敗時もモーダル警告を出しません。

## 構成

```text
project.godot                 Godot 4.6 / Compatibility / OpenXR設定
export_presets.cfg            Android arm64 / OpenXRの最小preset
openxr_action_map.tres        Quest/PICO/VIVE左右コントローラーのaim/grip pose
scenes/main.tscn              XR rig、環境、最小デモ
scripts/main.gd               OpenXR、MR、fallback初期化
docs/mr_toolkit_design.md     MRTK相当のインタラクション基盤の検討メモ
addons/godotopenxrvendors/    Meta/PICO/VIVE向けOpenXR Vendors plugin
```

## 今後の拡張の検討

このテンプレートの次の層として、MRTK3相当のインタラクション基盤（近接・遠隔のポインタ、押せるボタン、掴んで動かす操作、追従メニュー）を検討しています。方針と段階の案は[docs/mr_toolkit_design.md](docs/mr_toolkit_design.md)にまとめています。実装はまだ入っていません。

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
