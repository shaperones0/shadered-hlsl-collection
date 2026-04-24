cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texN : register(t0);
SamplerState smpN : register(s0);
float uP;

static const float3 C255 = float3(255.0, 255.0, 255.0);

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texN.Sample(smpN,uv);
    }
}

float hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = frac(p);

    float a = hash(i);
    float b = hash(i + float2(1, 0));
    float c = hash(i + float2(0, 1));
    float d = hash(i + float2(1, 1));

    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(lerp(a,b,u.x), lerp(c,d,u.x), u.y);
}

float fold(float val, int n) {
    return 1 - abs(1 - 2*frac(val * n));
}

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float3 sharpen(float3 x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float3 pal4(float f, float3 c0, float3 c1, float3 c2, float3 c3) {
    f = saturate(f) * 3.0;

    float3 col = c0;

    col = lerp(col, c1, saturate(f));
    col = lerp(col, c2, saturate(f - 1.0));
    col = lerp(col, c3, saturate(f - 2.0));

    return col;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    float3 matAlbedo = float3(0.0);

    float2 flow = float2(0.05, 0.03) * uTime;
    float2 warp = tex(0, uv*2.0 + flow).rg - 0.5;
    
    //base snoise
    float ns;
    {
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
        n1 = tex(0, float2(angle * 1 * 0.1, uTime * 0.002)).b;
        n1 = sharpen(n1+0.13,6);
        
        //apply the dark center
        float dark = (1.0 - dist * uP * (n1 * lerp(0,0.2,saturate(uP-1)) + 1));
        ns=saturate(ns-dark);
    
        //make uniformly darker spots
        ns=smoothstep(0.5,1,ns);
        //ns=round(ns);
    }
    
    //stylization
    float maskMain;
    {
        maskMain = step(1e-5,ns);
        
        //outer color dark
        float3 colOuter = float3(0.25, 0.05, 0.05);
        
        //inner lighter colors
        float2 innerFlow = float2(0.05, 0.03) * uTime;
        innerFlow *= pow(ns,5);
        float2 innerWarp = tex(0, uv * 5.0 + flow*5).rg - 0.5;
        innerFlow += innerWarp;
        innerFlow *= pow(ns,5);
        innerWarp = tex(0, uv * 5.0 + innerFlow * float2(-0.6, 0.8)).rg - 0.5;
        //shall only warp when inner
        innerWarp *= pow(ns,5);
        float innerWarpN = tex(0, uv * 1.0 - flow * float2(0.8, -0.9)).r;
        innerWarpN = saturate(innerWarpN*1.5 - 0.5);
        innerWarpN = lerp(0.05, 0.8, innerWarpN);
        innerWarp *= innerWarpN;
        float2 innerUvw = uv + innerWarp * 0.5;
        
        float n1 = vnoise(innerUvw * 2.0 * 5);
        float n2 = vnoise(-innerUvw * 3.0 * 5);
        float3 meatH[4] = {
            float3( 80.0,  21.0,  20.0) / C255,
            float3(121.0,   7.0,   7.0) / C255,
            float3(161.0,   6.0,   6.0) / C255,
            float3(255.0, 109.0, 109.0) / C255
        };

        float3 meatS[4] = {
            float3(161.0,  51.0,  73.0) / C255,
            float3(187.0,  56.0,  79.0) / C255,
            float3(182.0,  73.0,  73.0) / C255,
            float3(177.0, 102.0, 102.0) / C255
        };
        float3 colMeatH = pal4(n1,meatH[0],meatH[1],meatH[2],meatH[3]);
        float3 colMeatS = pal4(n1,meatS[0],meatS[1],meatS[2],meatS[3]);
        n2=pow(n2,0.8);
        float3 colInner = lerp(colMeatH, colMeatS, n2);
        
        float3 col = lerp(colOuter, colInner, pow(ns,2)) * maskMain;
        col = sharpen(col, 1.5);
        //col=colInner;
        //col=float3(innerWarpN);
        //col=float3(innerWarp,0.0);
        
        matAlbedo = col;// * maskMain;
    }
    
    return float4(matAlbedo,1.0f);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
