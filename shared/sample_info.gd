class_name SampleInfo
extends Resource

## 1つのサンプルの説明。`samples/samples.tres`が持ち、ランチャーが一覧を作る。

## `devices`のビット順と対応する端末名。
const DEVICE_NAMES: Array[String] = [
	"Quest 3",
	"PICO 4 Ultra",
	"VIVE Focus Vision",
	"Android XR",
]

@export var title := ""
@export_multiline var description := ""
@export_file("*.tscn") var scene := ""
## 動作する端末。0は「未確認」を意味する。
@export_flags("Quest 3", "PICO 4 Ultra", "VIVE Focus Vision", "Android XR") var devices := 0
## 必要な権限やextensionなど、一覧に出したい補足。
@export var notes := ""


## 対応端末を「Quest 3 / Android XR」の形にする。
func get_devices_text() -> String:
	if devices == 0:
		return "未確認"

	var names: Array[String] = []
	for index in DEVICE_NAMES.size():
		if devices & (1 << index):
			names.append(DEVICE_NAMES[index])

	if names.size() == DEVICE_NAMES.size():
		return "全機種"

	return " / ".join(names)
