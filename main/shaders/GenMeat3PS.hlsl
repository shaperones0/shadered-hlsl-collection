cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
    float2 uLightPos;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

static const float3 C255 = float3(255.0, 255.0, 255.0);

struct Material {
    float height;
    float3 albedo;
    float roughness;
};


float3 mod289(in float3 x) { return x - floor(x * (1. / 289.)) * 289.; }
float4 mod289(in float4 x) { return x - floor(x * (1. / 289.)) * 289.; }
float4 permute(in float4 x) { return mod289(((x * 34.0) + 1.0) * x); }
float4 taylorInvSqrt(in float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }
float3 quintic(const in float3 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }

//worley noise
#define RANDOM_SCALE float4(443.897, 441.423, 0.0973, 0.1099)
#define WORLEY_JITTER 1.0

float3 random3(float3 p) {
    p = frac(p * RANDOM_SCALE.xyz);
    p += dot(p, p.yzx + 19.19);
    return frac((p.xxy + p.yzz) * p.zyx);
}

float2 wnoise2(float3 p) {
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

float wnoise(float3 p) {
    return 1.0-wnoise2(p).x;
}

//perlin noise
float pnoise(in float3 P, in float3 rep) {
    float3 Pi0 = floor(P) % rep; // Integer part, modulo period
    float3 Pi1 = (Pi0 + float3(1.0, 1.0, 1.0)) % rep; // Integer part + 1, mod period
    Pi0 = mod289(Pi0);
    Pi1 = mod289(Pi1);
    float3 Pf0 = frac(P); // Fractional part for interpolation
    float3 Pf1 = Pf0 - float3(1.0, 1.0, 1.0); // Fractional part - 1.0
    float4 ix = float4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
    float4 iy = float4(Pi0.yy, Pi1.yy);
    float4 iz0 = Pi0.zzzz;
    float4 iz1 = Pi1.zzzz;

    float4 ixy = permute(permute(ix) + iy);
    float4 ixy0 = permute(ixy + iz0);
    float4 ixy1 = permute(ixy + iz1);

    float4 gx0 = ixy0 * (1.0 / 7.0);
    float4 gy0 = frac(floor(gx0) * (1.0 / 7.0)) - 0.5;
    gx0 = frac(gx0);
    float4 gz0 = float4(0.5, 0.5, 0.5, 0.5) - abs(gx0) - abs(gy0);
    float4 sz0 = step(gz0, float4(0.0, 0.0, 0.0, 0.0));
    gx0 -= sz0 * (step(0.0, gx0) - 0.5);
    gy0 -= sz0 * (step(0.0, gy0) - 0.5);

    float4 gx1 = ixy1 * (1.0 / 7.0);
    float4 gy1 = frac(floor(gx1) * (1.0 / 7.0)) - 0.5;
    gx1 = frac(gx1);
    float4 gz1 = float4(0.5, 0.5, 0.5, 0.5) - abs(gx1) - abs(gy1);
    float4 sz1 = step(gz1, float4(0.0, 0.0, 0.0, 0.0));
    gx1 -= sz1 * (step(0.0, gx1) - 0.5);
    gy1 -= sz1 * (step(0.0, gy1) - 0.5);

    float3 g000 = float3(gx0.x,gy0.x,gz0.x);
    float3 g100 = float3(gx0.y,gy0.y,gz0.y);
    float3 g010 = float3(gx0.z,gy0.z,gz0.z);
    float3 g110 = float3(gx0.w,gy0.w,gz0.w);
    float3 g001 = float3(gx1.x,gy1.x,gz1.x);
    float3 g101 = float3(gx1.y,gy1.y,gz1.y);
    float3 g011 = float3(gx1.z,gy1.z,gz1.z);
    float3 g111 = float3(gx1.w,gy1.w,gz1.w);

    float4 norm0 = taylorInvSqrt(float4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
    g000 *= norm0.x;
    g010 *= norm0.y;
    g100 *= norm0.z;
    g110 *= norm0.w;
    float4 norm1 = taylorInvSqrt(float4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
    g001 *= norm1.x;
    g011 *= norm1.y;
    g101 *= norm1.z;
    g111 *= norm1.w;

    float n000 = dot(g000, Pf0);
    float n100 = dot(g100, float3(Pf1.x, Pf0.yz));
    float n010 = dot(g010, float3(Pf0.x, Pf1.y, Pf0.z));
    float n110 = dot(g110, float3(Pf1.xy, Pf0.z));
    float n001 = dot(g001, float3(Pf0.xy, Pf1.z));
    float n101 = dot(g101, float3(Pf1.x, Pf0.y, Pf1.z));
    float n011 = dot(g011, float3(Pf0.x, Pf1.yz));
    float n111 = dot(g111, Pf1);

    float3 fade_xyz = quintic(Pf0);
    float4 n_z = lerp(float4(n000, n100, n010, n110), float4(n001, n101, n011, n111), fade_xyz.z);
    float2 n_yz = lerp(n_z.xy, n_z.zw, fade_xyz.y);
    float n_xyz = lerp(n_yz.x, n_yz.y, fade_xyz.x);
    return (2.2 * n_xyz + 1) * 0.5;
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

float2 warp(float2 uv, float t) {
    float2 w1 = float2(
        vnoise(uv * 2.0 + t * 0.15),
        vnoise(uv * 2.0 - t * 0.12)
    );

    float2 w2 = float2(
        vnoise(uv * 5.0 - t * 0.2),
        vnoise(uv * 5.0 + t * 0.18)
    );

    return (w1 * 2 - 1) * 0.15 + (w2 * 2 - 1) * 0.05;
}

float dither(float2 uv) {
    return frac(sin(dot(uv, float2(12.9898,78.233))) * 43758.5453);
}

float3 quantize(float3 col, float steps, float2 uv) {
    float3 c = col;

    float3 nois = dither(uv);

    c += (nois - 0.5)*0.5 / steps;

    c = floor(c * steps) / steps;

    return c;
}

float fold(float val, float n) {
    val = frac(val * n);
    return 1 - abs(1 - 2*val);
}

float3 pal4(float f, float3 c0, float3 c1, float3 c2, float3 c3) {
    f = saturate(f) * 3.0;

    float3 col = c0;

    col = lerp(col, c1, saturate(f));
    col = lerp(col, c2, saturate(f - 1.0));
    col = lerp(col, c3, saturate(f - 2.0));

    return col;
}

float pnoiseLVessels(in float3 v, in float3 rep) {
    float amplitude = 0.5;
    float frequency = 1.0;
    float output = 0.0;
    static const int octaves=4;
    for (int i = 0; i < octaves; i++)
    {
        output += (1-wnoise(v * frequency)) * amplitude;
        //output += pnoise(v * frequency, rep) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.1;
    }

    return clamp(output, 0.0, 1.0);
}


float maskVesselS(float2 uv, float scale, float smsMin) {
    float np = pnoiseLVessels(float3(uv * scale, 0.0),float3(20.0));
    np = fold(np, 1);
    np = pow(np, 5);
    np = smoothstep(smsMin, 0.9, np);
    return np;
}

float maskVesselL(float2 uv) {
    float np = pnoise(float3(uv * 4.0, 0.0),float3(20.0));
    np = fold(np, 1);
    np = pow(np, 4);
    np = smoothstep(0.5, 1, np);

    return np;
}

void matBase(inout Material m, float2 uv, float t) {
    float2 uvw = uv + warp(uv, 1.0f);

    float n1 = vnoise(uvw * 2.0 * 5);
    float n2 = vnoise(-uvw * 3.0 * 5);

    // color
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
    float3 col = lerp(colMeatH, colMeatS, n2);
    //col = float3(1.0f,0.0f,0.0f);

    // large cavities
    float cav = vnoise(uvw * 1.2 * 6);
    cav = pow(cav, 3) * pow(1-cav*0.8,1);
    //cav = smoothstep(0.6, 0.85, cav);
    //col -= cav;

    // invert for pits
    float height = -cav * 0.4;

    // roughness ---
    float rough = 0.6;
    rough -= n2 * 0.2; // fat smooth

    m.albedo = col;
    m.height = height;
    m.roughness = rough;
}

void matMediumVessels(inout Material m, float2 uv) {
    float2 uvw = uv + warp(uv, 1.0f)*10;


    float depthMask;
    //depthMask = pnoise(float3(uv * 1.3 * 8 + 20.0,1.0), float3(20.0));
    //depthMask *= pnoise(float3(uv * 1.3 * 3 + 15.0,1.0), float3(20.0));
    depthMask = vnoise(uvw * 1.3 * 8 + 20.0);
    //m.albedo=depthMask;
    float smsMin = lerp(0.8,0.0,depthMask);

    float density = vnoise(uv * 0.7 * 8 + 10.0);
    float scale = lerp(5.0, 35.0, density);

    float vessels = maskVesselS(uvw, scale, smsMin);

    float bulge = smoothstep(0.4, 0.8, depthMask);

    // height contribution
    m.height += vessels * lerp(-0.0, 0.001, bulge);

    // color
    float3 veinCol = float3(0.2, 0.0, 0.05);
    m.albedo = lerp(m.albedo, veinCol, vessels * 0.3);

    // roughness (wet veins)
    m.roughness -= vessels * 0.2;
}

void matSkin(inout Material m, float2 uv) {

    float density = vnoise(uv * 0.7 * 8 + 16.0);
    float scale = lerp(1.0, 1.2, density);
    float w = wnoise(float3(uv * 8.0 * 12.0 * scale, 0));

    float cells;
    cells = smoothstep(0.1, 0.3, w);

    // only where not bulging
    float mask = saturate(1.0 - m.height * 2.0);

    cells = smoothstep(0,1,w);
    m.height += cells * 0.0019 * mask;

    m.albedo *= 0.95 + cells * 0.1;
}

void matLargeVessel(inout Material m, float2 uv, float time) {
    float v = maskVesselL(uv);

    float heightMask = vnoise(uv * 1.0 + 50.0);

    float visible = smoothstep(0.3, 0.7, heightMask);

    // pulsation
    float pulse = 1.0 + 0.1 * sin(time * 4.0);

    float h = v * visible * pulse;

    m.height += h * 0.4;

    float3 col = float3(0.8, 0.05, 0.05);

    m.albedo = lerp(m.albedo, col, v * visible);

    m.roughness -= v * 0.3;
}

float evaluateHeight(float2 uv) {
    Material m;
    matBase(m, uv, uTime);

    matMediumVessels(m, uv);
    matSkin(m, uv);
    matLargeVessel(m, uv, uTime);
    //applyHoles(m, uv);

    return m.height;
}

float3 computeNormal(float2 uv) {
    float eps = 0.002;
    float strength = 1.5; // tweak this

    float h  = evaluateHeight(uv);
    float hx = evaluateHeight(uv + float2(eps, 0));
    float hy = evaluateHeight(uv + float2(0, eps));

    float3 n = float3(
        (h - hx) * strength,
        (h - hy) * strength,
        eps
    );

    return normalize(n);
}

float3 shade(Material m, float2 uv) {
    float3 n = computeNormal(uv);

    float3 lightDir = normalize(float3(uLightPos - uv, 0.3));
    float3 viewDir = float3(0,0,1);

    float diff = saturate(dot(n, lightDir));

    float heightFactor = saturate(m.height + 0.5);

    float3 halfDir = normalize(lightDir + viewDir);
    float spec = pow(saturate(dot(n, halfDir)), 16 + 48*(1-m.roughness));

    spec *= heightFactor; // IMPORTANT FIX

    float3 col = m.albedo * (0.4 + 0.6 * diff);
    col += spec * (1.0 - m.roughness);

    // subtle darkening in pits
    col *= 0.8 + 0.2 * heightFactor;

    return col;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    Material m;
    matBase(m, uv, uTime);
    matMediumVessels(m, uv);
    matSkin(m, uv);
    matLargeVessel(m, uv, uTime);
    //applyHoles(m, uv);

    float3 col;
    col = shade(m, uv);
    //col = m.albedo;

    //col = quantize(col, 6.0, uv);
    return float4(col,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
