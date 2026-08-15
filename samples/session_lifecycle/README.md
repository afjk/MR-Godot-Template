# セッションの扱い

リフレッシュレートの選択、フォーカスの喪失と復帰、recenterを見るサンプルです。

上のパネルに現在のレートと選べるレートの一覧、下のパネルに受け取った出来事が並びます。ヘッドセットを外す、ホームへ戻る、リセンターすると行が増えます。

## 見どころ

購読と処理は[`shared/mr_stage.gd`](../../shared/mr_stage.gd)にあります。全サンプルに効かせたいためです。

- **リフレッシュレート**: `get_available_display_refresh_rates()`から`maximum_refresh_rate`以下で最良のものを選び、`set_display_refresh_rate()`で適用します。あわせて`Engine.physics_ticks_per_second`を実測レートへ合わせ、トラッキング姿勢がフレーム境界に乗るようにします
- **フォーカス**: `session_visible`は起動時にも通るため、一度フォーカスを得た後の再訪だけを喪失とみなします。喪失中は`get_tree().paused`でツリーを止め、`MRStage`自身は`PROCESS_MODE_ALWAYS`で動かして復帰を受け取ります
- **recenter**: 何をどう置き直すかはアプリ次第なので、共通側は`pose_recentered`シグナルの中継だけを行います

## 必要な設定

なし。

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/session_lifecycle/sample.tscn`をエディタで開いてF6。
