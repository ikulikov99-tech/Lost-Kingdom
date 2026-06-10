// fog.gdshader — туман войны (полноэкранный шейдер в CanvasLayer)
//
// Работает в экранном пространстве.
// Конвертирует UV экрана → мировые координаты через позицию камеры.
// Рисует серые полупрозрачные "облака" там, где карта не открыта.

shader_type canvas_item;

// Позиция центра камеры в мировых координатах (обновляется каждый кадр)
uniform vec2  cam_pos    = vec2(-1112.0, -704.0);
uniform float cam_zoom   = 1.3;
uniform vec2  vp_size    = vec2(1280.0, 720.0);

// Позиция героя — визуальный reveal во время движения (не location unlock)
uniform vec2  hero_pos = vec2(-99999.0, -99999.0);
// hero_reveal_r >= reveal_r чтобы не было схлопывания при выходе из локации
uniform float hero_reveal_r = 160.0;

// Trail — пройденный путь (до 8 точек, сохраняются на время поездки)
// Не влияют на счётчик, очищаются при прибытии в локацию
uniform int   trail_count = 0;
uniform vec2  tp0 = vec2(-99999.0, -99999.0);
uniform vec2  tp1 = vec2(-99999.0, -99999.0);
uniform vec2  tp2 = vec2(-99999.0, -99999.0);
uniform vec2  tp3 = vec2(-99999.0, -99999.0);
uniform vec2  tp4 = vec2(-99999.0, -99999.0);
uniform vec2  tp5 = vec2(-99999.0, -99999.0);
uniform vec2  tp6 = vec2(-99999.0, -99999.0);
uniform vec2  tp7 = vec2(-99999.0, -99999.0);

// Открытые позиции (до 9 штук, по одной uniform на каждую)
uniform int   revealed_count = 0;
uniform vec2  rp0 = vec2(-99999.0, -99999.0);
uniform vec2  rp1 = vec2(-99999.0, -99999.0);
uniform vec2  rp2 = vec2(-99999.0, -99999.0);
uniform vec2  rp3 = vec2(-99999.0, -99999.0);
uniform vec2  rp4 = vec2(-99999.0, -99999.0);
uniform vec2  rp5 = vec2(-99999.0, -99999.0);
uniform vec2  rp6 = vec2(-99999.0, -99999.0);
uniform vec2  rp7 = vec2(-99999.0, -99999.0);
uniform vec2  rp8 = vec2(-99999.0, -99999.0);

// Радиус видимости и мягкость края
uniform float reveal_r    = 160.0;
uniform float edge_soft   = 40.0;

// Цвет тумана: серые облака с высокой прозрачностью в открытых зонах
uniform vec4 fog_color : source_color = vec4(0.08, 0.10, 0.16, 0.95);

void fragment() {
	// SCREEN_UV: (0,0)=верхний левый, (1,1)=нижний правый
	vec2 screen_px  = (SCREEN_UV - vec2(0.5)) * vp_size;   // пиксели от центра экрана
	vec2 world_pos  = cam_pos + screen_px / cam_zoom;       // мировые координаты

	// Постоянные открытые точки: discovered-локации + trail пройденного пути
	// Все используют один reveal_r → одинаковый радиус видимости
	float min_perm_d = 1e9;
	// Discovered локации
	if (revealed_count > 0) min_perm_d = min(min_perm_d, distance(world_pos, rp0));
	if (revealed_count > 1) min_perm_d = min(min_perm_d, distance(world_pos, rp1));
	if (revealed_count > 2) min_perm_d = min(min_perm_d, distance(world_pos, rp2));
	if (revealed_count > 3) min_perm_d = min(min_perm_d, distance(world_pos, rp3));
	if (revealed_count > 4) min_perm_d = min(min_perm_d, distance(world_pos, rp4));
	if (revealed_count > 5) min_perm_d = min(min_perm_d, distance(world_pos, rp5));
	if (revealed_count > 6) min_perm_d = min(min_perm_d, distance(world_pos, rp6));
	if (revealed_count > 7) min_perm_d = min(min_perm_d, distance(world_pos, rp7));
	if (revealed_count > 8) min_perm_d = min(min_perm_d, distance(world_pos, rp8));
	// Trail точки пройденного пути (очищаются при прибытии в локацию)
	if (trail_count > 0) min_perm_d = min(min_perm_d, distance(world_pos, tp0));
	if (trail_count > 1) min_perm_d = min(min_perm_d, distance(world_pos, tp1));
	if (trail_count > 2) min_perm_d = min(min_perm_d, distance(world_pos, tp2));
	if (trail_count > 3) min_perm_d = min(min_perm_d, distance(world_pos, tp3));
	if (trail_count > 4) min_perm_d = min(min_perm_d, distance(world_pos, tp4));
	if (trail_count > 5) min_perm_d = min(min_perm_d, distance(world_pos, tp5));
	if (trail_count > 6) min_perm_d = min(min_perm_d, distance(world_pos, tp6));
	if (trail_count > 7) min_perm_d = min(min_perm_d, distance(world_pos, tp7));

	// Текущая позиция героя (движется с ним, не location unlock)
	float hero_d = distance(world_pos, hero_pos);

	float fog_perm  = smoothstep(reveal_r - edge_soft, reveal_r + edge_soft, min_perm_d);
	float fog_hero  = smoothstep(hero_reveal_r - edge_soft, hero_reveal_r + edge_soft, hero_d);
	float fog_alpha = min(fog_perm, fog_hero);

	COLOR = vec4(fog_color.rgb, fog_color.a * fog_alpha);
}
