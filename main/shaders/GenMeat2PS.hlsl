cbuffer vars : register(b0)
{
    float2 uResolution;
    float uTime;
    float2 uLightPos;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

float hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);

    float a = hash(i);
    float b = hash(i + float2(1, 0));
    float c = hash(i + float2(0, 1));
    float d = hash(i + float2(1, 1));

    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
}

float2 warp(float2 uv, float t) {
    float2 w1 = float2(
        vnoise(uv * 2.0 + t * 0.15),
        vnoise(uv * 2.0 - t * 0.12)
    );

    float2 w2 = float2(
        vnoise(uv * 5.0 - t * 0.2),
        vnoise(uv * 5.0 + t * 0.18)
    );

    return (w1 * 2 - 1) * 0.15 + (w2 * 2 - 1) * 0.05;
}

struct MeatData {
    float base;     // flesh mass
    float veins;    // tendrils
    float micro;    // fine detail
    float flow;     // motion mask
};

MeatData MeatData_create(float2 uv, float t) {
    MeatData d;

    float2 uvw = uv + warp(uv, t);

    d.base  = vnoise(uvw * 2.5);
    float breakup = vnoise(uvw * 7.0);
    d.base *= (0.6 + 0.4 * breakup);

    d.veins = vnoise(uvw * 14.0);
    d.veins = 1.0 - abs(d.veins * 2.0 - 1.0);
    d.veins = pow(d.veins, 5.0);

    d.micro = vnoise(uvw * 30.0);

    d.flow  = vnoise(uvw * 5.0 + t * 0.5);

    return d;
}

float3 MeatData_albedo(MeatData d) {
    float t = d.base;

    float3 dark  = float3(0.12, 0.02, 0.02);
    float3 mid   = float3(0.5,  0.08, 0.08);
    float3 light = float3(0.85, 0.25, 0.2);
    float3 fat   = float3(0.7,  0.6,  0.25);

    float3 col = lerp(dark, mid, t);
    col = lerp(col, light, t * t);

    col *= 0.9 + 0.2 * d.micro;

    col = lerp(col, fat, pow(t, 4.0) * 0.3);

    return col;
}

float3 MeatData_roughness(MeatData d) {
    float r = 0.6;
    r -= d.veins * 0.4;
    r -= d.flow * 0.2;
    r += (d.micro - 0.5) * 0.1;
    return saturate(r);
}

float3 MeatData_height(MeatData d) {
    float h = 0.0;

    h += d.base * 0.2;
    h += d.veins * 0.25;
    h += d.micro * 0.05;

    return h;
}

float3 heightAt(float2 uv) {
    MeatData d = MeatData_create(uv, uTime);
    return MeatData_height(d);
}

float3 computeNormal(float2 uv) {
    float eps = 0.002;
    float strength = 2.0;

    float h  = heightAt(uv);
    float hx = heightAt(uv + float2(eps, 0));
    float hy = heightAt(uv + float2(0, eps));

    float3 n = float3(
        (h - hx) * strength,
        (h - hy) * strength,
        eps
    );

    return normalize(n);
}

float3 MeatData_lighting(float2 uv, MeatData d, float3 albedo) {
    float3 n = computeNormal(uv);

    float3 lightDir = normalize(float3(uLightPos - uv, 0.3));
    float3 viewDir  = float3(0,0,1);

    float diff = saturate(dot(n, lightDir));

    float rough = MeatData_roughness(d);
    float shininess = lerp(8.0, 64.0, 1.0 - rough);

    float3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(saturate(dot(n, halfDir)), shininess);

    float3 col = albedo * (0.3 + 0.7 * diff);
    col += spec * (1.0 - rough) * 0.8;

    // --- subsurface scattering ---
    float thickness = 1.0 - MeatData_height(d);
    float wrap = dot(n, lightDir) * 0.5 + 0.5;

    float sss = pow(wrap, 2.0) * thickness;
    float3 sssColor = float3(0.8, 0.2, 0.15);

    col += sss * sssColor * 0.5;

    return col;
}

float genVeins(float2 uv, float t) {
    float2 uvw = uv + warp(uv, t);

    float2 dir = normalize(float2(0.7, 0.3));
    float coord = dot(uvw, dir);

    float v = abs(sin(coord * 40.0));
    v = pow(v, 4.0);

    float n = vnoise(uvw * 10.0);
    v *= smoothstep(0.3, 0.7, n);

    return v;
}

float genBigVessels(float2 uv, float time) {
    float n = vnoise(uv * 1.5);

    float2 dir = normalize(float2(0.3, 0.9));
    float flow = dot(uv, dir);

    float v = 1.0 - abs(n - 0.5) * 2.0;
    v = pow(v, 3.0);

    v *= smoothstep(0.3, 0.7, sin(flow * 6.0));

    return v;
}

float genPores(float2 uv) {
    float n = vnoise(uv * 20.0);
    return smoothstep(0.7, 0.9, n);
}

float genMouths(float2 uv) {
    float n = vnoise(uv * 2.0);
    return smoothstep(0.6, 0.7, n);
}

float dither(float2 uv) {
    return frac(sin(dot(uv, float2(12.9898,78.233))) * 43758.5453);
}

float3 quantize(float3 col, float steps, float2 uv) {
    float3 c = col;

    float3 nois = dither(uv);

    c += (nois - 0.5) / steps;

    c = floor(c * steps) / steps;

    return c;
}

float lerp2(float a, float b, float c, float d, float v) {
    return c + (d - c) * ((v - a) / (b - a));
}

float fold(float val, float n) {
    val = frac(val * n);
    return 1 - abs(1 - 2*val);
}

float3 computeSSS(float sss) {
    float3 sssColor = float3(0.8, 0.2, 0.15);

    return sss * sssColor * 0.5;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    // motion
    uv = (uv - 0.5) * (1 + 0.03*sin(uTime*2)) + 0.5;

    // get data
    MeatData d = MeatData_create(uv * 2.5, uTime);

    // features
    float veins = genVeins(uv * 2.5, uTime);
    float bigVessels = genBigVessels(uv * 2.5, uTime);
    float pores = genPores(uv * 2.5);
    float mouths = genMouths(uv * 2.5);

    // material
    float3 col = MeatData_albedo(d);

    // integrate structures
    col = lerp(col, float3(0.2,0.0,0.05), veins);
    col = lerp(col, float3(0.4,0.0,0.05), bigVessels);

    // holes
    col *= 1.0 - pores * 0.3;
    col = lerp(col, float3(0.05,0.0,0.0), mouths);

    // lighting
    col = MeatData_lighting(uv * 2.5, d, col);

    // FINAL quantization
    //col = quantize(col, 6.0, uv);

    return float4(col, 1);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
