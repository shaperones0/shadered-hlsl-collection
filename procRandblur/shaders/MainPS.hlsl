cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg : register(t0);
SamplerState smpBg : register(s0);
float uRadius;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg.Sample(smpBg,uv);
    }
}

float hash(float2 p) {
    p = frac(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return frac(p.x * p.y);
}

#define PI 3.14159265
#define GOLDEN_ANGLE 2.39996323
float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    
    const int SAMPLES = 16;

    float2 pixel = uv*uResolution;//floor(uv / uTexelSize);

    // Stable per-pixel rotation
    float rotation = hash(pixel) * PI * 2.0;

    float3 accum = 0.0;
    float weightSum = 0.0;

    for (int i = 0; i < SAMPLES; i++)
    {
        float fi = (float)i + 0.5;

        // Uniform disk distribution
        float r = sqrt(fi / SAMPLES);

        // Golden-angle spiral
        float angle = fi * GOLDEN_ANGLE + rotation;

        float2 dir = float2(cos(angle), sin(angle));

        float2 offset =
            dir *
            r *
            uRadius / uResolution
            ;

        float2 uvo = uv + offset;
        uvo=saturate(uvo);
        float3 c = tex(0, uvo).rgb;

        // Gaussian-ish weighting
        float w = exp(-r * r * 4.0);

        accum += c * w;
        weightSum += w;
    }

    return float4(accum / weightSum, 1.0);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
