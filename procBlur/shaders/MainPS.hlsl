cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg : register(t0);
SamplerState smpBg : register(s0);
float2 res;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg.Sample(smpBg,uv);
    }
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    float4 color = tex(0, uv) * 0.2270270270;

    // pair (1,2)
    float2 o1 = res * 1.3846153846;
    color += tex(0, uv + o1) * 0.3162162162;
    color += tex(0, uv - o1) * 0.3162162162;

    // pair (3,4)
    float2 o2 = res * 3.2307692308;
    color += tex(0, uv + o2) * 0.0702702703;
    color += tex(0, uv - o2) * 0.0702702703;

    return float4(color.rgb,1.0f);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
