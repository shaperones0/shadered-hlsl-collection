cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texN : register(t0);
SamplerState smpN : register(s0);
float uP;

float3 mod289(in float3 x) { return x - floor(x * (1. / 289.)) * 289.; }
float4 mod289(in float4 x) { return x - floor(x * (1. / 289.)) * 289.; }
float4 permute(in float4 x) { return mod289(((x * 34.0) + 1.0) * x); }
float4 taylorInvSqrt(in float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texN.Sample(smpN,uv);
    }
}

float snoise(float3 v) {
    const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);

    // First corner
    float3 i  = floor(v + dot(v, C.yyy));
    float3 x0 = v   - i + dot(i, C.xxx);

    // Other corners
    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);

    // x1 = x0 - i1  + 1.0 * C.xxx;
    // x2 = x0 - i2  + 2.0 * C.xxx;
    // x3 = x0 - 1.0 + 3.0 * C.xxx;

    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy;
    float3 x3 = x0 - 0.5;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    float4 p =
      permute(permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0))
                            + i.y + float4(0.0, i1.y, i2.y, 1.0))
                            + i.x + float4(0.0, i1.x, i2.x, 1.0));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float4 j = p - 49.0 * floor(p / 49.0);  // mod(p,7*7)
    float4 x_ = floor(j / 7.0);
    float4 y_ = floor(j - 7.0 * x_);  // mod(j,N)

    float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
    float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;

    float4 h = 1.0 - abs(x) - abs(y);

    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);

    //float4 s0 = float4(lessThan(b0, 0.0)) * 2.0 - 1.0;
    //float4 s1 = float4(lessThan(b1, 0.0)) * 2.0 - 1.0;

    float4 s0 = floor(b0) * 2.0 + 1.0;
    float4 s1 = floor(b1) * 2.0 + 1.0;
    float4 sh = -step(h, 0.0);

    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    float3 g0 = float3(a0.xy, h.x);
    float3 g1 = float3(a0.zw, h.y);
    float3 g2 = float3(a1.xy, h.z);
    float3 g3 = float3(a1.zw, h.w);

    // Normalise gradients
    float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
    g0 *= norm.x;
    g1 *= norm.y;
    g2 *= norm.z;
    g3 *= norm.w;

    // Mix final noise value
    float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;
    m = m * m;

    float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
    return 42.0 * dot(m, px);
}

float snoisel(float3 v) {
    float amplitude = 0.25;
    float frequency = 0.5;
    float output = 0.0;
    static const int octaves=5;
    for (int i = 0; i < octaves; i++) {
        output += (2*snoise(v * frequency)+1) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.1;
    }

    return saturate(output);
}

float snoisev(float3 v) {
    float amplitude = 0.5;
    float frequency = 1;
    float output = 0.0;
    static const int octaves=3;
    for (int i = 0; i < octaves; i++) {
        output += (2*snoise(v * frequency)+1) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return saturate(output);
}

float fold(float val, int n) {
    return 1 - abs(1 - 2*frac(val * n));
}

float fnoise(float3 uv) {
    uv *= 0.5;
    float2 uv2 = uv.xy + tex(0, uv.xy + uv.z * 0.5).rb;
    float n0 = tex(0, uv.xy).r;
    float n1 = tex(0, uv.xy).b;
    //float n2 = tex(0, uv.xy + uv.z * float2(0.02,0.03));
    float n = lerp(n0, n1, uv.z*10);
    n = smoothstep(-1,1,sin(uv.z*(n1-n0)*100.0)); 
    //n = sin(n);
    return n;//lerp(n0, n1, fold(uv.z,1));
}

float fnoisev(float3 v) {
    float amplitude = 0.5;
    float frequency = 1;
    float output = 0.0;
    static const int octaves=1;
    for (int i = 0; i < octaves; i++) {
        output += (2*fnoise(v * frequency)+1) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return saturate(output);
}

float sharpenFast(float x, float k) {
    x = saturate(x);
    float a = x * x;
    float b = (1 - x) * (1 - x);
    return a / (a + b + 1e-5) * k + x * (1 - k);
}

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float fnoisea(float3 v) {
    float2 flow = float2(0.05, 0.03);
    return tex(0, v.xy + flow * v.z).r;
}

float fnoisav(float3 v) {
    float2 flow = float2(0.05, 0.03);
    float amplitude = 0.5;
    float frequency = 1;
    float output = 0.0;
    static const int octaves=3;
    for (int i = 0; i < octaves; i++) {
        output += fnoisea(v * frequency) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.0;
    }

    return saturate(output);
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //base simplex noise (5 octave, low frequency)
    float2 flow = float2(0.05, 0.03) * uTime;
    float2 warp = tex(0, uv*2.0 + flow).rg - 0.5;

    //uvw *= 0.5;
    
    //base snoise
    float nois = tex(0, uv*0.8 + warp*0.2/20).b;
    
    //ridges
    float ns=1-fold(saturate(nois),3);

    //make the center dark
    float2 d = uv - 0.5f;
    float dist = length(d);

    //1d radial simplex noise to jostle the border
    float2 d2 = float2(
        d.x * 0.707 - d.y * 0.707,
        d.x * 0.707 + d.y * 0.707
    );
    float angle = sign(d2.y) * (1 - d2.x / (abs(d2.x) + abs(d2.y) + 1e-5));
    float n1;
    n1 = sharpen(fnoisav(float3(angle * 5 * 0.1, 1.0, uTime * 0.2))+0.13, 6);
    n1 = tex(0, float2(angle * 5 * 0.1, uTime * 0.02));
    n1 = sharpen(n1+0.13,6);
    //n1 = sharpen(fnoisav(float3(angle * 5 * 0.1, 1.0, uTime * 0.2))+0.13, 6);
    
    //apply the dark center
    float dark = (1.0 - dist * uP * (n1 * 0.1 + 1));
    ns=saturate(ns-dark);
    //ns=saturate(ns-(1.0-dist*uP*(n1*0.2+1.2)));

    //make uniformly darker spots
    ns=smoothstep(0.5,1,ns);
    //ns=dark;
    return float4(ns,ns,ns,1.0f);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
