cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texN : register(t0);
SamplerState smpN : register(s0);
float uP;

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texN.Sample(smpN,uv);
    }
}

float fold(float val, int n) {
    return 1 - abs(1 - 2*frac(val * n));
}

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //base simplex noise (5 octave, low frequency)
    float2 flow = float2(0.05, 0.03) * uTime;
    float2 warp = tex(0, uv*2.0 + flow).rg - 0.5;
    
    //base snoise
    float ns;
    ns = tex(0, uv*0.8 + warp*0.2/20).b;
    ns = 1-fold(saturate(ns),3);

    //make the center dark
    float2 d = uv - 0.5f;
    float dist = length(d);

    //1d radial noise to jostle the border
    float2 d2 = float2(
        d.x * 0.707 - d.y * 0.707,
        d.x * 0.707 + d.y * 0.707
    );
    float angle = sign(d2.y) * (1 - d2.x / (abs(d2.x) + abs(d2.y) + 1e-5));
    float n1;
    n1 = tex(0, float2(angle * 5 * 0.1, uTime * 0.02)).b;
    n1 = sharpen(n1+0.13,6);
    
    //apply the dark center
    float dark = (1.0 - dist * uP * (n1 * 0.1 + 1));
    ns=saturate(ns-dark);

    //make uniformly darker spots
    ns=smoothstep(0.5,1,ns);
    return float4(ns,ns,ns,1.0f);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
