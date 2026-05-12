cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texN : register(t0);
SamplerState smpN : register(s0);

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texN.Sample(smpN,uv);
    }
}

// maf

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float lerp2(float fromA, float fromB, float toA, float toB, float value) {
    return ((value-fromA)/(fromB-fromA))*(toB-toA)+toA;
}

// hash

float hash(float2 p) {
    p = frac(p * 0.3183099 + float2(0.71, 0.113));
    p *= 17.0;
    return frac(p.x * p.y * (p.x + p.y));
}

#define RANDOM_SCALE float4(443.897, 441.423, 0.0973, 0.1099)
float2 hash2(float p) {
    float3 p3 = frac(float3(p, p, p) * RANDOM_SCALE.xyz);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz) * p3.zy);
}

float hashSmooth(float2 uv, float time) {
    float z = time;
    float iz = floor(z);
    float f = frac(z);
    f = sharpen(f, 1.2);

    // 3-tap weights
    float w0 = 0.5 * (1.0 - f) * (1.0 - f);
    float w1 = 0.75 - (f - 0.5)*(f - 0.5);
    float w2 = 0.5 * f * f;

    float2 base = uv;

    float n0 = hash(base + hash2(iz - 1)).r;
    float n1 = hash(base + hash2(iz)).r;
    float n2 = hash(base + hash2(iz + 1)).r;

    float result = n0*w0 + n1*w1 + n2*w2;

    return result;
}

// fake 3d perlin noise using pre-baked 2d texture
float pnoise(float2 uv, float time) {
    float z = time;
    float iz = floor(z);
    float f = frac(z);
    f = sharpen(f, 1.2);

    // 3-tap weights
    float w0 = 0.5 * (1.0 - f) * (1.0 - f);
    float w1 = 0.75 - (f - 0.5)*(f - 0.5);
    float w2 = 0.5 * f * f;

    float2 base = uv.xy;

    float n0 = tex(0, base + hash2(iz - 1)).r;
    float n1 = tex(0, base + hash2(iz)).r;
    float n2 = tex(0, base + hash2(iz + 1)).r;

    float result = n0*w0 + n1*w1 + n2*w2;

    return result;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    float c;
    c = pnoise(uv, uTime);
    //c = (c - 0.5) * 1.3;
    //c = (c / (1.0 + abs(c))) * 0.5 + 0.5;
    c = smoothstep(0.2,1,c);
    c = sharpen(c, 2);
    c *= hashSmooth(uv*98+10.123,uTime*2);
    
    
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
