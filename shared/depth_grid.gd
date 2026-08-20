class_name DepthGrid
extends RefCounted

## 環境深度の画像を、XRの基準空間の点の格子に変換する。
##
## `realtime_planes`・`realtime_mesh_collision`・`realtime_plane_clusters`の3つが
## 同じ変換を書いていたので、規約どおりここへ寄せました。深度マップの取得
## （`get_environment_depth_map_async`）はサンプル側の主題なので、こちらには
## 入れていません。ここにあるのは座標の変換だけです。
##
## 座標の対応はOpenXR Vendors plugin同梱の再投影シェーダーに合わせてあります。
## シェーダーは`uv = ndc.xy * 0.5 + 0.5`でテクスチャを引き、深度を
## `depth * 2.0 - 1.0`でNDCへ広げています。**GodotのUVは上下が逆**（UVのyが
## 増えると画像の下へ進む）なので、NDCのy=+1（視界の上）は画像の下の行に
## 当たります。ここを取り違えると点群が上下に鏡写しになり、位置は合っているのに
## 面の向きだけ合わない、という気づきにくい壊れ方をします。


## NDC上の1点を、深度を読んで基準空間の位置へ戻す。取れない場合はVector3.ZERO。
static func unproject(ndc_xy: Vector2, image: Image, inverse: Projection) -> Vector3:
	var uv := ndc_xy * 0.5 + Vector2(0.5, 0.5)
	var pixel := Vector2i(
		clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1),
		clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
	)
	var raw := image.get_pixel(pixel.x, pixel.y).r
	if is_zero_approx(raw):
		# シェーダー側も0は「深度なし」として捨てている。
		return Vector3.ZERO

	var clip := inverse * Vector4(ndc_xy.x, ndc_xy.y, raw * 2.0 - 1.0, 1.0)
	if is_zero_approx(clip.w):
		return Vector3.ZERO

	return Vector3(clip.x, clip.y, clip.z) / clip.w


## 視界を格子状に間引いて点にする。戻り値は行の配列で、各要素はVector3かnull。
## 並びは法線や三角形を作るのに使うので、取れなかった点もnullとして残します。
##
## `extent`は視界のどこまでを使うかをNDCで指定します（1.0で端まで）。端は歪みと
## ノイズが大きいので、少し内側にするのが実用的です。`view_origin`は距離の判定に
## 使うカメラ位置で、点と同じ基準空間で渡してください。
static func sample(
	image: Image,
	inverse: Projection,
	steps: int,
	extent: float,
	view_origin: Vector3,
	min_distance: float,
	max_distance: float
) -> Array:
	var grid: Array = []
	for row in steps:
		var line: Array = []
		for column in steps:
			# 行が増えるほど視界の下へ進む（NDCのyは上が+1）。
			var ndc_xy := Vector2(
				(float(column) / (steps - 1) * 2.0 - 1.0) * extent,
				(1.0 - float(row) / (steps - 1) * 2.0) * extent
			)
			var point := DepthGrid.unproject(ndc_xy, image, inverse)
			var distance := point.distance_to(view_origin)
			if point == Vector3.ZERO or distance < min_distance or distance > max_distance:
				line.append(null)
				continue

			line.append(point)

		grid.append(line)

	return grid
