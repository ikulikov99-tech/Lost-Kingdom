// fog.gdshader — туман войны для Lost Kingdom
// Покрывает карту тёмным туманом, оставляя круги видимости вокруг открытых локаций.

shader_type canvas_item;

const int MAX_LOCS = 9;

// Количество открытых локаций
uniform int revealed_count = 0;

// Позиции открытых локаций в мировых координатах (x0,y0, x1,y1, ...)
uniform float revealed_xy[18];

// Радиус видимости вокруг каждой открытой локации
uniform float reveal_radius = 270.0;
// Мягкость края тумана
uniform float edge_soft = 80.0;
// Цвет тумана
uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.08, 0.88);

// Передаём мировую позицию вершины в фрагментный шейдер
varying vec2 world_pos;

void vertex() {
	// VERTEX — позиция в локальном пространстве узла (= мировое, т.к. FogOverlay в (0,0))
	world_pos = VERTEX;
}

void fragment() {
	float min_dist = 1e9;
	for (int i = 0; i < revealed_count && i < MAX_LOCS; i++) {
		float px = revealed_xy[i * 2];
		float py = revealed_xy[i * 2 + 1];
		float d = distance(world_pos, vec2(px, py));
		min_dist = min(min_dist, d);
	}
	// smoothstep: 0 = полностью видно, 1 = полный туман
	float fog = smoothstep(reveal_radius - edge_soft, reveal_radius + edge_soft, min_dist);
	COLOR = vec4(fog_color.rgb, fog_color.a * fog);
}
