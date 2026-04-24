cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

float uSeed;

float hash(float2 p, float2 period) {
    p = fmod(p, period);
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// Cheap value noise (GOOD ENOUGH for baking)
float vnoise(float2 p, float2 period) {
    float2 i = floor(p);
    float2 f = frac(p);

    float a = hash(i, period);
    float b = hash(i + float2(1,0), period);
    float c = hash(i + float2(0,1), period);
    float d = hash(i + float2(1,1), period);

    float2 u = f*f*(3.0-2.0*f);

    return lerp(a, b, u.x) +
           (c - a)*u.y*(1.0-u.x) +
           (d - b)*u.x*u.y;
}

// FBM for base noise
float fbm(float2 p, float2 period) {
    float v = 0.0;
    float a = 0.5;

    v += vnoise(p, period) * a;
    p *= 2.0; period *= 2.0; a *= 0.5;

    v += vnoise(p, period) * a;
    p *= 2.0; period *= 2.0; a *= 0.5;

    v += vnoise(p, period) * a;
    p *= 2.0; period *= 2.0; a *= 0.5;

    v += vnoise(p, period) * a;

    return v;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    // Tileable coordinates
    float2 p = uv * 8.0;
    float2 period = float2(8.0);

    // R: base FBM noise
    float base = fbm(p, period);
    float base2 = fbm(p + 5.0, period);

    // G: warp field (different frequency)
    float warp = fbm(p * 2.3 + uSeed, period);

    return float4(base, warp, base2, 1);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
