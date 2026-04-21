cbuffer vars : register(b0)
{
    float2 uResolution;
    float uTime;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

#define RANDOM_SCALE float4(443.897, 441.423, 0.0973, 0.1099)
#define WORLEY_JITTER 1.0

float3 random3(float3 p) {
    p = frac(p * RANDOM_SCALE.xyz);
    p += dot(p, p.yzx + 19.19);
    return frac((p.xxy + p.yzz) * p.zyx);
}

float2 worley2(float3 p) {
    float3 n = floor( p );
    float3 f = frac( p );

    float distF1 = 1.0;
    float distF2 = 1.0;
    float3 off1, pos1;
    float3 off2, pos2;
    for (int k=-1; k<=1; k++) {
        for (int j=-1; j<=1; j++) {
            for (int i=-1; i<=1; i++) {
                float3 g = float3(i,j,k);
                float3 o = random3(n + g) * WORLEY_JITTER;
                float3 p = g + o;
                float d = distance(p, f);
                if (d < distF1) {
                    distF2 = distF1;
                    distF1 = d;
                    off2 = off1;
                    off1 = g;
                    pos2 = pos1;
                    pos1 = p;
                }
                else if (d < distF2) {
                    distF2 = d;
                    off2 = g;
                    pos2 = p;
                }
            }
        }
    }

    return float2(distF1, distF2);
}

float worley(float3 p) {
    return 1.0-worley2(p).x;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    float c=worley(float3(uv*10,uTime));
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
