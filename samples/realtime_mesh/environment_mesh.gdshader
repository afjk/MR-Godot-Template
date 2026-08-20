shader_type spatial;
render_mode unshaded, cull_disabled;

// 環境深度から毎フレーム作り直す環境メッシュ。
//
// 格子メッシュの各頂点を、そのUVの位置の深度で押し出すだけです。CPUは一切
// 触りません。pluginが毎フレーム更新するグローバルuniformを頂点シェーダーから
// 直接読みます。
//
// 座標の対応はplugin同梱のenvironment_depth.gdshaderに合わせてあります。
//   uv = ndc.xy * 0.5 + 0.5、深度は0..1で、NDCのzは depth * 2.0 - 1.0
//
// 逆行列が返すのはXRの基準空間なので、このノードはXROrigin3Dの直下に置き、
// 結果をVERTEX（モデル空間）へそのまま入れます。ワールドへはGodotが運びます。

global uniform highp sampler2DArray META_ENVIRONMENT_DEPTH_TEXTURE : filter_nearest, repeat_disable, hint_default_black;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT;
global uniform bool META_ENVIRONMENT_DEPTH_AVAILABLE;

// 0 = 格子線、1 = 面
uniform int display_mode : hint_range(0, 1) = 0;
// カメラの位置（基準空間）。距離の色分けと有効範囲の判定に使う。
uniform vec3 view_origin = vec3(0.0);
// 有効とみなす距離。Metaの資料では約0.2〜4m。
uniform float min_distance = 0.2;
uniform float max_distance = 4.0;
// 格子の1マスぶんのUV。隣の頂点を見るのに使う。
uniform vec2 grid_step = vec2(0.01);
// 隣の頂点とこれ以上離れていたら、物の境目とみなして描かない。
uniform float edge_threshold = 0.15;
// 格子線の密度と太さ。
uniform float grid_density = 48.0;
uniform float grid_width = 0.06;

uniform vec3 near_color : source_color = vec3(0.20, 0.90, 0.65);
uniform vec3 far_color : source_color = vec3(0.25, 0.45, 0.95);

varying float valid;
varying float distance_ratio;

// 深度画像の1点を基準空間の位置へ戻す。深度が無い場所はwに0を返す。
// 位置自体は最遠面のものを返すので、穴があってもメッシュは裂けない。
vec4 unproject(vec2 uv) {
	// 頂点シェーダーには微分が無いので、textureLodで明示的に読む。
	float depth = textureLod(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(clamp(uv, 0.0, 1.0), 0.0), 0.0).r;
	float has_depth = depth > 0.0 ? 1.0 : 0.0;
	depth = mix(1.0, depth, has_depth);

	vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
	vec4 point = META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT * ndc;
	if (abs(point.w) < 1e-6) {
		return vec4(0.0);
	}

	return vec4(point.xyz / point.w, has_depth);
}

void vertex() {
	// PlaneMeshのUVは0..1。これをそのまま深度画像の座標として使う。
	vec4 center = unproject(UV);
	VERTEX = center.xyz;
	valid = 0.0;
	distance_ratio = 0.0;

	if (!META_ENVIRONMENT_DEPTH_AVAILABLE || center.w < 0.5) {
		return;
	}

	float view_distance = distance(center.xyz, view_origin);
	if (view_distance < min_distance || view_distance > max_distance) {
		return;
	}

	// 隣の頂点を2つだけ見て、物の縁で引き伸ばされた三角形を落とす。
	vec4 right = unproject(UV + vec2(grid_step.x, 0.0));
	vec4 down = unproject(UV + vec2(0.0, grid_step.y));
	float gap = 0.0;
	if (right.w > 0.5) {
		gap = max(gap, distance(right.xyz, center.xyz));
	}
	if (down.w > 0.5) {
		gap = max(gap, distance(down.xyz, center.xyz));
	}
	if (gap > edge_threshold) {
		return;
	}

	valid = 1.0;
	distance_ratio = clamp(
			(view_distance - min_distance) / max(max_distance - min_distance, 1e-3), 0.0, 1.0);
}

void fragment() {
	// 頂点で落とした部分は、補間が1未満になるところまで含めて捨てる。
	if (valid < 0.9) {
		discard;
	}

	vec3 color = mix(near_color, far_color, distance_ratio);

	if (display_mode == 0) {
		// UVの格子で線を描く。rendererに依存しないワイヤーフレーム。
		vec2 cell = abs(fract(UV * grid_density) - 0.5);
		if (min(cell.x, cell.y) > grid_width) {
			discard;
		}

		ALBEDO = color;
		return;
	}

	ALBEDO = color * 0.85;
}
