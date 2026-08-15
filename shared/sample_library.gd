class_name SampleLibrary
extends Resource

## サンプル一覧の定義。ランチャーはこれを読んでメニューを作る。
## サンプルを追加するときは、自分のフォルダと`samples/samples.tres`の1行だけを触る。

@export var samples: Array[Resource] = []


## `SampleInfo`として取り出す。壊れた要素は黙って捨てる。
func get_entries() -> Array[SampleInfo]:
	var entries: Array[SampleInfo] = []
	for entry in samples:
		var info := entry as SampleInfo
		if info != null and not info.scene.is_empty():
			entries.append(info)

	return entries
