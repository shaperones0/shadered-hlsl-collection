cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texM : register(t0);
SamplerState smpM : register(s0);

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texM.Sample(smpM,uv);
    }
}

float3 blendNormal(float3 src, float3 dest, float srcA) { return srcA * src + (1.0 - srcA) * dest; }
float uP2;

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    
    
    float t1 = tex(0,uv + float2(1,0) / uResolution).r;
    float t2 = tex(0,uv - float2(1,0) / uResolution).r;
    float t3 = tex(0,uv + float2(0,1) / uResolution).r;
    float t4 = tex(0,uv - float2(0,1) / uResolution).r;
    float avg = (t1+t2+t3+t4) * 0.25;
    float mx = max(max(t1,t2),max(t3,t4));
    float p = smoothstep(0.7,2,uP2);
    p=pow(p,1.5);
    float3 colOutline = float3(lerp(0.2,1.0,p), 0.1*avg, 0.1*avg);
    
    float o = step(1e-5, t1) * step(1e-5, t2) * step(1e-5, t3) * step(1e-5, t4);
    
    o = (step(1e-5, tex(0,uv).r)) * (1-o);
    
    float4 c = tex(0, uv);
    c = float4(blendNormal(colOutline, c.rgb, o),1.0f);
    
    return c;
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
