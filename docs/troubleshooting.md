# トラブルシューティング

ビルドと実機動作でつまずきやすい点をまとめています。手順そのものは[docs/build.md](build.md)を参照してください。


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

Godot OpenXR Vendors 5.0以降には、Khronosの[OpenXR Validation Layers](https://www.khronos.org/blog/new-openxr-validation-layer-helps-developers-build-robustly-portable-xr-applications)がAndroidライブラリとして同梱されています。GodotのOpenXR呼び出しが仕様どおりかを実機で検証でき、サンプルを改造して動かなくなったときの切り分けに使えます。

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

