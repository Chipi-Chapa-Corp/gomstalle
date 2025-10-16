// Godot 4.4 — draw red where the walls SubViewport has any color
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, blend_mix;

uniform sampler2D walls_mask : filter_nearest, repeat_disable; // ViewportTexture
uniform sampler2D depth_tex  : hint_depth_texture, filter_nearest, repeat_disable;
uniform bool  use_occlusion  = true;      // true = only when behind something
uniform bool  reverse_z      = true;      // 4.4 default
uniform float depth_eps      = 1e-4;
uniform float mask_thresh    = 0.01;      // any non-black counts
uniform bool  flip_y         = false;
uniform vec3  color          = vec3(1.0, 0.0, 0.0);

void fragment(){
    // 1) gate by mask color
    vec2 mu = vec2(SCREEN_UV.x, flip_y ? 1.0 - SCREEN_UV.y : SCREEN_UV.y);
    vec3 c  = texture(walls_mask, mu).rgb;
    float m = max(c.r, max(c.g, c.b));
    if (m < mask_thresh) { discard; }

    // 2) optionally require “behind something”
    if (use_occlusion){
        float sd = texture(depth_tex, SCREEN_UV).r;
        float md = FRAGCOORD.z;
        bool occ = reverse_z ? (md + depth_eps < sd) : (md - depth_eps > sd);
        if (!occ) { discard; }
    }

    ALBEDO = color;
    EMISSION = vec3(0.0);
    ALPHA = 1.0;
}
