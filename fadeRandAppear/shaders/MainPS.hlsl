cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg1 : register(t0);
SamplerState smpBg1 : register(s0);
Texture2D texBg2 : register(t1);
SamplerState smpBg2 : register(s2);

float uLevel;
float uFalloff;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg1.Sample(smpBg1,uv);
    }
    else if (i == 1) {
        return texBg2.Sample(smpBg2,uv);
    }
}

float hash(float2 p) {
    p = frac(p * 0.3183099 + float2(0.71, 0.113)) * 17.0;
    return frac(p.x * p.y * (p.x + p.y));
}

float hashSmooth(float2 uv, float time) {
    return (sin(hash(uv) * 6.283185 + time) + 1.0) * 0.5;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    
    float2 ml = uResolution/32;
    
    float c = (sin(uTime) + 1) * 0.55;
    float4 col1 = tex(0,uv);
    float4 col2 = tex(1,uv);
    
    float level = saturate(uLevel);
    
    float k, ks;
    k = hashSmooth(floor(uv*ml),uTime*2);
    ks = k;
    float lMin,lMax;
    float p = lerp(1,2,hash(floor(-uv*ml*2)));
    lMin = pow(level,p);
    lMax = pow(level,1/p);
    k = lerp(lMin,lMax,k);
    k = 1-(1-k)*(1-step(uFalloff,p-1));
    
    return lerp(col1,col2,k);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
