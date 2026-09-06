shader_type spatial;
render_mode unshaded, cull_disabled;
void fragment() {
 float across = abs(UV.y * 2.0 - 1.0);
 float flow = sin(UV.x * 5.0 - TIME * 3.5 + sin(UV.y * 14.0 + UV.x));
 float filaments = pow(abs(sin(UV.y * 20.0 + sin(UV.x * 2.0 - TIME)*1.3)), 9.0);
 vec3 deep = vec3(0.025, 0.07, 0.19);
 vec3 teal = vec3(0.1, 0.65, 0.72);
 vec3 violet = vec3(0.40, 0.18, 0.72);
 vec3 color = mix(deep, mix(teal,violet,0.5+0.5*sin(UV.x*.65)), 0.28 + filaments*.45);
 color += teal * pow(across, 13.0) * (0.55 + flow*.25);
 ALBEDO = color;
}
