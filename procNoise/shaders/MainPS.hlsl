cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg : register(t0);
SamplerState smpBg : register(s0);
float uAmount;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg.Sample(smpBg,uv);
    }
}

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

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float fnoisev3(float3 uv) {
    float z = uv.z;
    float iz = floor(z);
    float f = frac(z);
    f = sharpen(f, 1.2);

    // 3-tap weights
    float w0 = 0.5 * (1.0 - f) * (1.0 - f);
    float w1 = 0.75 - (f - 0.5)*(f - 0.5);
    float w2 = 0.5 * f * f;

    float2 base = uv.xy;

    float n0 = hash(base + hash2(iz - 1)).r;
    float n1 = hash(base + hash2(iz)).r;
    float n2 = hash(base + hash2(iz + 1)).r;

    float result = n0*w0 + n1*w1 + n2*w2;

    return result;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    float4 c = tex(0, uv);
    float n = fnoisev3(float3(uv*1007,uTime*2));
    c+=(2*n-1)*uAmount;
    return c;
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
