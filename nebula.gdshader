shader_type spatial;
render_mode unshaded, cull_disabled;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p), f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
float fbm(vec2 p) {
 float v=0.0, a=.5;
 for(int i=0;i<5;i++){v+=noise(p)*a;p=p*2.04+vec2(3.7,1.1);a*=.5;}
 return v;
}
void fragment() {
 vec2 p=UV*vec2(7.0,5.0);
 float n=fbm(p+vec2(fbm(p+TIME*.001),fbm(p+8.0)));
 float cloud=smoothstep(.34,.76,n);
 vec3 color=mix(vec3(.012,.019,.055),vec3(.12,.06,.25),cloud);
 float filament=pow(fbm(p*1.8+5.0),4.0);
 color+=vec3(.035,.15,.21)*filament*2.0;
 ALBEDO=color;
}
