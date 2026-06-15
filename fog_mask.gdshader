// fog_mask.gdshader — маска видимости тумана войны
//
// Рисуется ПОСЛЕДНИМ внутри FogViewport с blend_mul:
// dst.a *= src.a → альфа всех облачных слоёв под маской умножается
// на fog_alpha (1 = туман остаётся, 0 = открытая зона, облака стёрты).
//
// Только маска. Облачный визуал — в fog_base.gdshader и puff-спрайтах.
// Края рвёт текстура fog_edge_mask.png (вместо процедурного FBM).

shader_type canvas_item;
render_mode blend_mul;

// ── Камера (каждый кадр из FogOverlay.update_camera) ──
uniform vec2  cam_pos  = vec2(-1112.0, -704.0);
uniform float cam_zoom = 1.3;
uniform vec2  vp_size  = vec2(1280.0, 720.0);
uniform float time     = 0.0;

// ── Герой ──
uniform vec2  hero_pos      = vec2(-99999.0, -99999.0);
// Маленький live-круг вокруг героя при движении (полное раскрытие локации —
// только при прибытии через rp*). 160 -> 80 -> 65.
uniform float hero_reveal_r = 65.0;

// ── Trail (FIFO 8 точек) ──
uniform int  trail_count = 0;
uniform vec2 tp0 = vec2(-99999.0, -99999.0);
uniform vec2 tp1 = vec2(-99999.0, -99999.0);
uniform vec2 tp2 = vec2(-99999.0, -99999.0);
uniform vec2 tp3 = vec2(-99999.0, -99999.0);
uniform vec2 tp4 = vec2(-99999.0, -99999.0);
uniform vec2 tp5 = vec2(-99999.0, -99999.0);
uniform vec2 tp6 = vec2(-99999.0, -99999.0);
uniform vec2 tp7 = vec2(-99999.0, -99999.0);

// ── Открытые локации (до 9) ──
uniform int  revealed_count = 0;
uniform vec2 rp0 = vec2(-99999.0, -99999.0);
uniform vec2 rp1 = vec2(-99999.0, -99999.0);
uniform vec2 rp2 = vec2(-99999.0, -99999.0);
uniform vec2 rp3 = vec2(-99999.0, -99999.0);
uniform vec2 rp4 = vec2(-99999.0, -99999.0);
uniform vec2 rp5 = vec2(-99999.0, -99999.0);
uniform vec2 rp6 = vec2(-99999.0, -99999.0);
uniform vec2 rp7 = vec2(-99999.0, -99999.0);
uniform vec2 rp8 = vec2(-99999.0, -99999.0);

// ── Параметры видимости ──
uniform float reveal_r  = 135.0;   // полное раскрытие локации (rp*) при прибытии
uniform float trail_r   = 70.0;    // тонкая дорога (tp*) во время движения
uniform float edge_soft = 18.0;

// ── Рваные края: контрастная noise mask, два масштаба ──
uniform sampler2D edge_tex : repeat_enable, filter_linear_mipmap;
uniform float edge_amp       = 75.0;  // амплитуда рваности локаций (px)
uniform float edge_amp_hero  = 30.0;  // у ореола героя
uniform float edge_amp_trail = 18.0;  // у trail-дороги (тонкая)

void fragment() {
    vec2 screen_px = (UV - vec2(0.5)) * vp_size;
    vec2 world_pos = cam_pos + screen_px / cam_zoom;

    // Медленный дрейф маски краёв — границы «дышат»
    vec2 drift = vec2(time * 0.010, time * 0.007);

    // Два масштаба: крупный — языки и карманы, мелкий — рваная кромка
    float n_big   = texture(edge_tex, world_pos * 0.0019 + drift).r;
    float n_small = texture(edge_tex, world_pos * 0.0062 - drift * 1.6).r;
    // Комбинация в диапазон ≈ -1..1, крупный шум доминирует
    float edge_n = (n_big * 0.72 + n_small * 0.42) * 2.0 - 1.14;

    // Локации (rp*) — полный радиус reveal_r (раскрываются при прибытии)
    float min_loc_d = 1e9;
    if (revealed_count > 0) min_loc_d = min(min_loc_d, distance(world_pos, rp0));
    if (revealed_count > 1) min_loc_d = min(min_loc_d, distance(world_pos, rp1));
    if (revealed_count > 2) min_loc_d = min(min_loc_d, distance(world_pos, rp2));
    if (revealed_count > 3) min_loc_d = min(min_loc_d, distance(world_pos, rp3));
    if (revealed_count > 4) min_loc_d = min(min_loc_d, distance(world_pos, rp4));
    if (revealed_count > 5) min_loc_d = min(min_loc_d, distance(world_pos, rp5));
    if (revealed_count > 6) min_loc_d = min(min_loc_d, distance(world_pos, rp6));
    if (revealed_count > 7) min_loc_d = min(min_loc_d, distance(world_pos, rp7));
    if (revealed_count > 8) min_loc_d = min(min_loc_d, distance(world_pos, rp8));

    // Trail (tp*) — маленький радиус trail_r: тонкая дорога, не раскрывает
    // здания рядом во время движения
    float min_trail_d = 1e9;
    if (trail_count > 0) min_trail_d = min(min_trail_d, distance(world_pos, tp0));
    if (trail_count > 1) min_trail_d = min(min_trail_d, distance(world_pos, tp1));
    if (trail_count > 2) min_trail_d = min(min_trail_d, distance(world_pos, tp2));
    if (trail_count > 3) min_trail_d = min(min_trail_d, distance(world_pos, tp3));
    if (trail_count > 4) min_trail_d = min(min_trail_d, distance(world_pos, tp4));
    if (trail_count > 5) min_trail_d = min(min_trail_d, distance(world_pos, tp5));
    if (trail_count > 6) min_trail_d = min(min_trail_d, distance(world_pos, tp6));
    if (trail_count > 7) min_trail_d = min(min_trail_d, distance(world_pos, tp7));

    float hero_d = distance(world_pos, hero_pos);

    float r_loc    = reveal_r + edge_n * edge_amp;
    float fog_loc  = smoothstep(r_loc - edge_soft, r_loc + edge_soft, min_loc_d);

    float r_trail   = trail_r + edge_n * edge_amp_trail;
    float fog_trail = smoothstep(r_trail - edge_soft, r_trail + edge_soft, min_trail_d);

    float r_hero   = hero_reveal_r + edge_n * edge_amp_hero;
    float fog_hero = smoothstep(r_hero - edge_soft, r_hero + edge_soft, hero_d);

    // Туман убирается там, где близок ЛЮБОЙ источник → min по источникам
    float fog_alpha = min(min(fog_loc, fog_trail), fog_hero);

    // blend_mul: rgb=1 не меняет цвет, alpha умножает прозрачность слоёв ниже
    COLOR = vec4(1.0, 1.0, 1.0, fog_alpha);
}
