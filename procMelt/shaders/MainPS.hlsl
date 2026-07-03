cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg : register(t0);
SamplerState smpBg : register(s0);
Texture2D texNoise : register(t1); 
SamplerState smpNoise : register(s1);
float uAmount;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg.Sample(smpBg, uv);
    } else if (i == 1) {
        return texNoise.Sample(smpNoise, uv);
    }
    return float4(0, 0, 0, 0);
}

float hash(float2 p) {
    p = frac(p * 0.3183099 + float2(0.71, 0.113)) * 17.0;
    return frac(p.x * p.y * (p.x + p.y));
}

float hashSmooth(float2 uv, float time) {
    return (sin(hash(uv) * 6.283185 + time) + 1.0) * 0.5;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    float3 noiseData = tex(1, uv * float2(uResolution.x / uResolution.y, 1.0) * 0.25).rgb;
    
    float warpFactor = smoothstep(0.15, 0.0, noiseData.r - uAmount) * step(uAmount, noiseData.r);
    float2 distortedUV = uv + (noiseData.gb * 2.0 - 1.0) * warpFactor * 0.08; 
    
    float4 c = tex(0, distortedUV);

    float alpha = step(uAmount + 0.005, noiseData.r);
    float edge = smoothstep(uAmount + 0.05, uAmount, noiseData.r) * alpha;
    

    float3 cnoise = lerp(
        float3(hashSmooth(uv * 1003.0, uTime * 8.0) * 0.5), 
        float3(0.5), 
        smoothstep(uAmount + 0.01, uAmount + 0.004, noiseData.r)
    );

    c.rgb = lerp(c.rgb, cnoise, edge);

    float charring = smoothstep(uAmount + 0.15, uAmount + 0.05, noiseData.r) * (1.0 - edge);
    c.rgb *= 1.0 - (charring * 0.5);

    return float4(c.rgb, c.a * alpha);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    float4 col = mainC(uv.xy / uResolution);
    return col * col.a; 
}