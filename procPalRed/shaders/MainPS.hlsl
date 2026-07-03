cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg : register(t0);
SamplerState smpBg : register(s0);
float uRedThresh;
float uRedAmount;
float uSpotlight;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg.Sample(smpBg,uv);
    }
}

float hash(float2 p) {
    p = frac(p * 0.3183099 + float2(0.71, 0.113)) * 17.0;
    return frac(p.x * p.y * (p.x + p.y));
}

float hashSmooth(float2 uv, float time) {
    return (sin(hash(uv) * 6.283185 + time) + 1.0) * 0.5;
}

float lerp2(float fromA, float fromB, float toA, float toB, float value) {
    return ((value-fromA)/(fromB-fromA))*(toB-toA)+toA;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    float4 c = tex(0, uv);
    //spotlight
    {
        float2 uvs = uv;
        //square uv
        {
            float w=uResolution.x;
            float h=uResolution.y;
            if (w>h) {
                //multiply height
                uvs.y = lerp2(h-w, h+w, 0, 1, uvs.y * 2*h);
            }
            else {
                //multiply width
                uvs.x = lerp2(w-h, w+h, 0, 1, uvs.x * 2*w);
            }
        }
        //actuall nah
        uvs=uv;
        //randblur circle
        float2 hw = float2(hashSmooth(uvs * 1001.0, uTime), hashSmooth(uvs * 993.0, uTime) * 6.2831853);
        float2 centeredUV = uvs - 0.5 + sqrt(hw.x) * float2(cos(hw.y), sin(hw.y)) * 0.05;

        //spinning spiral tihngie
        float dist = length(centeredUV);
        float distortedDist = dist + sin((atan2(centeredUV.y, centeredUV.x) + dist * 5.0 - uTime * 0.5) * 8.0) * 0.15 * dist;

        float outerEdge = (1.0 - uSpotlight) * 1.5 - 0.2;
        c.rgb *= 1.0 - smoothstep(outerEdge - 0.4, outerEdge, distortedDist);
    }

    //palette
    float luma = pow(abs(dot(c.rgb, float3(0.299, 0.587, 0.114))), 1.2);
    float3 palColor = lerp(float3(0.0, 0.0, 0.0), float3(24.0, 24.0, 24.0) / 255.0, step(0.05, luma));
    palColor = lerp(palColor, float3(58.0, 58.0, 58.0) / 255.0, step(0.15, luma));
    palColor = lerp(palColor, float3(99.0, 99.0, 99.0) / 255.0, step(0.45, luma));

    //red
    float redMask = smoothstep(uRedThresh, uRedThresh + 0.15, c.r - max(c.g, c.b)) * step(0.15, c.r);
    return float4(lerp(palColor, c.rgb, redMask * uRedAmount), 1.0);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}