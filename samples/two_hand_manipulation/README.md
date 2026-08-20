# 両手操作

両手で掴んで回転・拡縮するサンプルです。片手だけなら移動と回転になります。

## 見どころ

掴んだ瞬間の状態を覚えておき、毎フレーム差分を掛け直すだけです。覚えるのは3つ。

- **両手を結ぶベクトル**（`_start_vector`）: 長さの比が倍率、向きの差が回転
- **両手の中点**（`_start_center`）: 回転と拡縮の中心
- **そのときのオブジェクトの姿勢**（`_start_transform`）

```gdscript
var wanted := _start_scale * vector.length() / _start_vector.length()
_scale = clampf(wanted, MIN_SCALE, MAX_SCALE)     # 制約を先に効かせる
var factor := _scale / _start_scale                # 実際に掛ける比を出し直す
var rotation := Basis(Quaternion(_start_vector.normalized(), vector.normalized()))
```

**制約を先に効かせてから比を出し直す**のが要点です。先に姿勢を作ってから後で押し戻すと、上限に張り付いた状態で手を動かしたときに位置がずれます。

- 手の数が変わった瞬間に「持ち直し」（`_rebase()`）ます。これが無いと、片手から両手へ移るときにオブジェクトが飛びます
- 掴み始めだけ距離を見て、掴んだ後は手が離れても持ち続けます。拡縮では手がオブジェクトから離れていくためです
- 掴む姿勢の取り方は`grab_object`と同じです（手のひら、またはgrip pose）

## 分かっている制限

**手のひねりは見ていません。** 両手を軸周りに回しても、その軸の回転は反映されません。MRTKの`ObjectManipulator`は両手の回転も混ぜて扱いますが、ここでは短さを優先しています。

## 必要な設定

- 手で掴むには`xr/openxr/extensions/hand_tracking=true`
- コントローラーは`openxr_action_map.tres`の`grab`アクション（`squeeze/value`）

## 対応端末

Quest 3 / PICO 4 Ultra / VIVE Focus Vision / Android XR

## 単体で動かす

`samples/two_hand_manipulation/sample.tscn`をエディタで開いてF6。
