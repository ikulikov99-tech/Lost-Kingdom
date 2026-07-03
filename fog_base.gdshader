// fog_base.gdshader — базовый слой тумана (tileable noise)
//
// Рисуется ПЕРВЫМ внутри FogViewport (под puff-облаками и маской).
// Два масштаба fog_density.png с разным дрейфом → неоднородная плотность.
// Привязан к мировым координатам — туман «лежит» на карте, не на экране.

shader_type canvas_item;

uniform vec2  cam_pos  = vec2(-1112.0, -704.0);
uniform float cam_zoom = 1.3;
uniform vec2  vp_size  = vec2(1280.0, 720.0);
uniform float time     = 0.0;

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

// Тёмно-синий мистический тон (неоткрытое заметно темнее)
uniform vec4 fog_tint : source_color = vec4(0.035, 0.046, 0.085, 1.0);

void fragment() {
    vec2 screen_px = (UV - vec2(0.5)) * vp_size;
    vec2 world_pos = cam_pos + screen_px / cam_zoom;

    // Крупный слой — медленный дрейф вправо-вниз
    vec2 drift1 = vec2(time * 0.006,  time * 0.004);
    // Мелкий слой — дрейф влево, чуть быстрее → параллакс
    vec2 drift2 = vec2(-time * 0.009, time * 0.005);

    float n1 = texture(noise_tex, world_pos * 0.00040 + drift1).r;
    float n2 = texture(noise_tex, world_pos * 0.00115 + drift2).r;

    // Комбинированная плотность: крупные массы + мелкая рябь
    float density = clamp(n1 * 0.65 + n2 * 0.45, 0.0, 1.0);

    // Светлее в плотных местах — облака, а не грязь
    vec3 rgb = fog_tint.rgb * (0.70 + density * 0.85);

    float alpha = fog_tint.a * (0.82 + density * 0.18);

    COLOR = vec4(rgb, alpha);
}
