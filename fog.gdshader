// fog.gdshader — туман войны с FBM-облаками
//
// Fullscreen shader в CanvasLayer (screen-space).
// Конвертирует SCREEN_UV → мировые координаты через cam_pos + screen_px / cam_zoom.
//
// Визуал: FBM noise даёт рваные облачные края и неравномерную плотность тумана.
// Логика: uniforms reveal_r / rp* / tp* не меняются — вся игровая механика в Main.gd.

shader_type canvas_item;

// ── Камера (каждый кадр из FogOverlay.update_camera) ─────────────────────────
uniform vec2  cam_pos  = vec2(-1112.0, -704.0);
uniform float cam_zoom = 1.3;
uniform vec2  vp_size  = vec2(1280.0, 720.0);
uniform float time     = 0.0;   // Time.get_ticks_msec() * 0.001, для дрейфа тумана

// ── Герой ────────────────────────────────────────────────────────────────────
uniform vec2  hero_pos      = vec2(-99999.0, -99999.0);
uniform float hero_reveal_r = 160.0;

// ── Trail — пройденный путь (8 точек, FIFO, очищается при прибытии) ───────────
uniform int  trail_count = 0;
uniform vec2 tp0 = vec2(-99999.0, -99999.0);
uniform vec2 tp1 = vec2(-99999.0, -99999.0);
uniform vec2 tp2 = vec2(-99999.0, -99999.0);
uniform vec2 tp3 = vec2(-99999.0, -99999.0);
uniform vec2 tp4 = vec2(-99999.0, -99999.0);
uniform vec2 tp5 = vec2(-99999.0, -99999.0);
uniform vec2 tp6 = vec2(-99999.0, -99999.0);
uniform vec2 tp7 = vec2(-99999.0, -99999.0);

// ── Открытые локации (до 9) ───────────────────────────────────────────────────
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

// ── Параметры видимости ───────────────────────────────────────────────────────
uniform float reveal_r  = 135.0;  // базовый радиус постоянного раскрытия
uniform float edge_soft = 18.0;   // мягкость края (до добавления шума)

// ── Цвет тумана ───────────────────────────────────────────────────────────────
uniform vec4 fog_color : source_color = vec4(0.07, 0.09, 0.15, 0.98);

// ══════════════════════════════════════════════════════════════════════════════
// FBM NOISE
// ══════════════════════════════════════════════════════════════════════════════

float hash(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
    q += dot(q, q.yzx + 19.19);
    return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);  // smoothstep для гладкой интерполяции
    return mix(
        mix(hash(i),               hash(i + vec2(1.0, 0.0)), u.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

// 4 октавы FBM — баланс качества и производительности
// Ротация между октавами убирает ось-артефакты
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(vec2(0.80, 0.60), vec2(-0.60, 0.80));
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p  = rot * p * 2.1 + vec2(5.2, 1.3);
        a *= 0.5;
    }
    return v;  // диапазон ≈ 0..1
}

// ══════════════════════════════════════════════════════════════════════════════
// FRAGMENT
// ══════════════════════════════════════════════════════════════════════════════

void fragment() {
    // ── Мировые координаты пикселя ──
    vec2 screen_px = (SCREEN_UV - vec2(0.5)) * vp_size;
    vec2 world_pos = cam_pos + screen_px / cam_zoom;

    // ── Медленный дрейф облаков ──
    vec2 drift = vec2(time * 0.018, time * 0.011);

    // ── Слой 1: шум для рваных краёв раскрытия (крупная октава) ──
    // Диапазон fbm ≈ 0..1 → смещаем в -1..1, умножаем на амплитуду
    float edge_n  = fbm(world_pos * 0.0038 + drift) * 2.0 - 1.0;
    float edge_px = edge_n * 52.0;   // ±52px — рваные края

    // ── Слой 2: внутренняя текстура тумана (мелкая октава) ──
    float cloud_n = fbm(world_pos * 0.0072 + drift * 1.5);

    // ── Минимальное расстояние до постоянно открытых точек ──
    float min_perm_d = 1e9;
    if (revealed_count > 0) min_perm_d = min(min_perm_d, distance(world_pos, rp0));
    if (revealed_count > 1) min_perm_d = min(min_perm_d, distance(world_pos, rp1));
    if (revealed_count > 2) min_perm_d = min(min_perm_d, distance(world_pos, rp2));
    if (revealed_count > 3) min_perm_d = min(min_perm_d, distance(world_pos, rp3));
    if (revealed_count > 4) min_perm_d = min(min_perm_d, distance(world_pos, rp4));
    if (revealed_count > 5) min_perm_d = min(min_perm_d, distance(world_pos, rp5));
    if (revealed_count > 6) min_perm_d = min(min_perm_d, distance(world_pos, rp6));
    if (revealed_count > 7) min_perm_d = min(min_perm_d, distance(world_pos, rp7));
    if (revealed_count > 8) min_perm_d = min(min_perm_d, distance(world_pos, rp8));
    if (trail_count > 0) min_perm_d = min(min_perm_d, distance(world_pos, tp0));
    if (trail_count > 1) min_perm_d = min(min_perm_d, distance(world_pos, tp1));
    if (trail_count > 2) min_perm_d = min(min_perm_d, distance(world_pos, tp2));
    if (trail_count > 3) min_perm_d = min(min_perm_d, distance(world_pos, tp3));
    if (trail_count > 4) min_perm_d = min(min_perm_d, distance(world_pos, tp4));
    if (trail_count > 5) min_perm_d = min(min_perm_d, distance(world_pos, tp5));
    if (trail_count > 6) min_perm_d = min(min_perm_d, distance(world_pos, tp6));
    if (trail_count > 7) min_perm_d = min(min_perm_d, distance(world_pos, tp7));

    float hero_d = distance(world_pos, hero_pos);

    // ── Туман с рваными краями ──
    // reveal_r смещён на edge_px → пятна раскрытия нецилиндрические
    float r_perm = reveal_r + edge_px;
    float fog_perm = smoothstep(r_perm - edge_soft, r_perm + edge_soft, min_perm_d);

    // Герой: чуть меньше шума — его ореол более стабилен, но тоже живой
    float r_hero = hero_reveal_r + edge_n * 22.0;
    float fog_hero = smoothstep(r_hero - edge_soft, r_hero + edge_soft, hero_d);

    float fog_alpha = min(fog_perm, fog_hero);

    // ── Облачная текстура тела тумана ──
    // cloud_n 0..1 → density 0.84..1.0 — видимые перепады плотности
    float density = fog_color.a * (0.86 + cloud_n * 0.16);
    density = clamp(density, 0.82, 1.0);

    // Лёгкое осветление облаков в более плотных местах — глубина
    vec3 cloud_rgb = fog_color.rgb * (0.82 + cloud_n * 0.36);

    COLOR = vec4(cloud_rgb, density * fog_alpha);
}
