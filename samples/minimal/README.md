# 最小構成

新しいプロジェクトを始めるときの出発点です。MRの土台の上に立方体を1つ置くだけの、いちばん短いサンプルです。

## これだけでMRになる理由

MRとして成立するために要るものは、すべて[`shared/mr_stage.gd`](../../shared/mr_stage.gd)にあります。

- OpenXRの起動状態とAlpha environment blend対応の確認、非対応時のデスクトップfallback
- `XROrigin3D`、`XRCamera3D`、左右のaim / gripコントローラー
- runtimeが提供する最良のdisplay refresh rateの選択
- ヘッドセットを外したときの一時停止と、復帰での再開

サンプル側に残るのはこれだけです。

```gdscript
func _ready() -> void:
	_stage = await SampleBootstrap.stage_async()
	# ここに自分のものを置く
```

`await`しているのは、`SampleBootstrap`がリグを挿し終わるのを待つためです。ランチャーから開いてもF6で単体実行しても、同じ書き方で動きます。

## 自分のプロジェクトへ持ち出す

1. `shared/`をまるごとコピーする
2. このフォルダ（または気に入ったサンプルのフォルダ）をコピーする
3. `project.godot`の`[autoload]`に`SampleBootstrap="*res://shared/sample_bootstrap.gd"`を足す
4. `project.godot`の`[xr]`セクションと`openxr_action_map.tres`をコピーする
5. `export_presets.cfg`から端末のpresetをコピーする

サンプルは`shared/`以外に依存しない決まりなので、この手順で動きます。**動かないものがあれば規約違反なので、issueにしてください。**

必要な設定はサンプルごとに違います。各サンプルのスクリプト冒頭に「必要なもの」として書いてあります。

## 気をつけること

**実世界を覆う不透明な床や壁を置かないでください。** MRではこれが最大の禁じ手です。Godotのテンプレートにありがちな「地面のPlane」をそのまま置くと、パススルーが全部隠れます。

## 対応端末

全機種。

## 単体で動かす

`samples/minimal/sample.tscn`をエディタで開いてF6。
