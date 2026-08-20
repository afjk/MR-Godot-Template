# 空間アンカー

実空間の位置に印を打ち、**アプリを再起動しても同じ場所に残す**サンプルです。AR Foundationの`ARAnchorManager`に当たります。

- 右手のpinch: 見ている先にアンカーを作り、そのまま永続化する
- 左手のpinch: 最後に作ったアンカーを消す（永続化も取り消す）

前回の起動から復元されたアンカーは**橙**、この起動で作ったアンカーは**水色**で出ます。

## 「座標を保存する」のとは違う

自分でTransformをファイルに書いても、次に起動したときに同じ場所には戻りません。原点はrecenterで動きますし、そもそも起動ごとに違う場所に置かれます。

空間アンカーは**runtimeが実空間の特徴を見て位置を復元します**。部屋を出て戻っても、机の同じ角に残ります。

## 見どころ

Godot 4.6 coreの`OpenXRSpatialAnchorCapability`を使います。ベンダー拡張ではないので、対応runtimeなら機種を問いません。

```gdscript
# XROrigin3Dのローカル座標で位置を渡す
var tracker: Object = _capability.call(&"create_new_anchor", Transform3D(Basis(), local))

# 永続化は非同期。OpenXRFutureResultで完了を待つ
var future: Object = _capability.call(&"persist_anchor", tracker, RID(), Callable())
future.connect(&"completed", _on_persist_completed)
```

作られたアンカーは`XRServer`にトラッカーとして登録されるので、表示は`plane_detection`とまったく同じ書き方になります。**`XRAnchor3D`に名前を渡すだけで、姿勢は追従します。**

前回のアンカーの復元も、アプリ側は何も書きません。`enable_builtin_anchor_detection`が有効なら、起動時にruntimeから戻ってきて`tracker_added`が飛んできます。**UUIDの保存も、再問い合わせも不要です。**

## 実装で外せない点

**消す順番。** 永続化されたアンカーは`remove_anchor()`で消せません。先に`unpersist_anchor()`を呼び、**その完了を待ってから**`remove_anchor()`です。Godot側にも「must first be made unpersistent」というチェックが入っています。

**コールバックの引数。** `persist_anchor`と`unpersist_anchor`の`user_callback`には**対象のトラッカーがそのまま渡り、成功したときだけ呼ばれます**。失敗も知りたい場合は、戻り値の`OpenXRFutureResult`の`completed`シグナルを使い、`get_result_value()`（bool）を見ます。このサンプルは両方を使い分けています。

**anchorトラッカーは平面と同居する。** `XRServer.TRACKER_ANCHOR`には平面検出のトラッカーも入ってきます。`is OpenXRAnchorTracker`で選り分けます。

## 確認のしかた

1. アンカーをいくつか置く（水色の立方体）
2. アプリを終了して、もう一度起動する
3. 同じ場所に**橙の立方体**として戻っていれば成功

原点がずれていても実空間の同じ場所に出ることが要点なので、置いた位置を実物（机の角など）で覚えておくと分かりやすいです。

## 必要な設定

`project.godot`（すべて設定済み）:

- `xr/openxr/extensions/spatial_entity/enabled`
- `.../enable_spatial_anchors`
- `.../enable_persistent_anchors`
- `.../enable_builtin_anchor_detection`

## 対応端末

`XR_EXT_spatial_anchor`と`XR_EXT_spatial_persistence`を公開するruntimeのみ。非対応端末では理由を表示します。永続化だけ非対応の場合は、その回限りのアンカーとして動きます。

## 単体で動かす

`samples/spatial_anchor/sample.tscn`をエディタで開いてF6。
