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

float3 mod289(in float3 x) { return x - floor(x * (1. / 289.)) * 289.; }
float4 mod289(in float4 x) { return x - floor(x * (1. / 289.)) * 289.; }
float4 permute(in float4 x) { return mod289(((x * 34.0) + 1.0) * x); }
float4 taylorInvSqrt(in float4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

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

    return clamp(output, 0.0, 1.0);
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

    return output;//clamp(output, 0.0, 1.0);
}

float hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

#define RANDOM_SCALE float4(443.897, 441.423, 0.0973, 0.1099)
float2 hash2(float p) {
    float3 p3 = frac(float3(p, p, p) * RANDOM_SCALE.xyz);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz) * p3.zy);
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

float2 swirlWithSpirals(float2 uv, float2 center, float radius, float time) {
    float2 dir = uv - center;
    float dist = length(dir);
    if (dist < radius) {
        float angle = atan2(dir.y, dir.x);
        float spiralFactor = (radius - dist) / radius;
        float spiralSpeed = 2.0;
        float distanceFactor = saturate(length(uv-center)/radius);
        distanceFactor=pow(distanceFactor,0.5);
        float spiralStrength = 5.0*distanceFactor;// * ; // Adjust the strength of the spiral arms

        float spiralTime = time * spiralSpeed + spiralFactor * spiralStrength;
        float spiralAngle = spiralTime + spiralFactor * sin(spiralTime);
        float spiralRadius = radius * (1.0 - spiralFactor * 0.5);
        float spiralUV = spiralRadius * float2(cos(angle + spiralAngle), sin(angle + spiralAngle));

        uv = center + lerp((uv-center),spiralUV,distanceFactor);
    }
    return uv;
}

float2 swirl2(float2 uv, float2 center, float radius) {
    float2 tc = uv;
    tc -= center;
    float dist = length(tc);
    float swirliness=-0.4;
    float radius_scaled = radius;
    if (dist < radius_scaled) {
        float percent = (radius_scaled - dist) / radius_scaled;
        float theta = percent * percent * swirliness * 8.0;
        float s = sin(theta);
        float c = cos(theta);
        tc = float2(dot(tc, float2(c, -s)), dot(tc, float2(s, c)));
    }
    return tc+center;
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

float fnoisev3(float3 uv) {
    float z = uv.z;
    float iz = floor(z);
    float f = frac(z);
    f = sharpen(f, 1.2);

    // 3-tap weights
    float w0 = 0.5 * (1.0 - f) * (1.0 - f);
    float w1 = 0.75 - (f - 0.5)*(f - 0.5);
    float w2 = 0.5 * f * f;

    float2 base = uv.xy;

    float n0 = tex(0, base + hash2(iz - 1)).r;
    float n1 = tex(0, base + hash2(iz)).r;
    float n2 = tex(0, base + hash2(iz + 1)).r;

    float result = n0*w0 + n1*w1 + n2*w2;

    return result;
}

float lerp2(float fromA, float fromB, float toA, float toB, float value) {
    return ((value-fromA)/(fromB-fromA))*(toB-toA)+toA;
}

float fnoisex(float3 uv) {
    //return fnoisev3(uv);
    float n = fnoisev3(uv);

    // mimic multi-octave contrast
    n = (n - 0.5);
    n *= 1.3;
    n = n / (1.0 + abs(n));
    n = n * 0.5 + 0.5;

    return sharpen(n,3);
    //return lerp(fnoisev3(uv), fnoisev3(uv + 1.5), 0.5);
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
    //normalize uv
    {
        float w=uResolution.x;
        float h=uResolution.y;
        if (w>h) {
            //multiply height
            uv.y = lerp2(h-w, h+w, 0, 1, uv.y * 2*h);
        }
        else {
            //multiply width
            uv.x = lerp2(w-h, w+h, 0, 1, uv.x * 2*w);
        }
    }

    //warp to lower part of the screen
    uv.y=pow(uv.y,0.5);
    //swirl
    //uv = swirlWithSpirals(uv, float2(0.5,0.5), 0.7, 0);
    uv = swirl2(uv, float2(0.5,0.5), 0.7);





    float3 matAlbedo = float3(0.0);

    float2 flow = float2(0.05, 0.03) * uTime;
    float2 warp = tex(0, uv*2.0 + flow).rg - 0.5;

    //base snoise
    float ns;
    {
        ns = tex(0, uv*0.8 + warp*0.2/20).b;
        ns = snoisel(float3(uv.x*10,uv.y*10,uTime/10));
        ns = 1-fold(saturate(ns),3);

        //make the center dark
        float2 d = uv - 0.5f;
        float dist = pow(length(d),0.7);//+0.1;

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
        float df=n1 * lerp(0,0.2,saturate(uP-1)) + 1;
        float dark = (1.0 - dist * uP * df);
        ns=saturate(ns-dark);

        //make uniformly darker spots
        ns=smoothstep(0.5,1,ns);
        //ns=df;
        //ns=round(ns);
    }

    //stylization
    float maskMain;
    {
        maskMain = step(1e-5,ns);

        //outer color dark
        float3 colOuter = float3(0.25, 0.05, 0.05);

        //inner lighter colors
        float innerWarpN = fnoisex(float3(uv*5, uTime));
        float2 innerUvw = uv + innerWarpN * 0.5;

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
        float3 colInner = lerp(colMeatH, colMeatS, pow(n2,0.8));

        float3 col = lerp(colOuter, colInner, pow(ns,2)) * maskMain;
        //col = sharpen(col, 1.5);

        matAlbedo = col;
    }

    float nr=step(0.5,ns);
    return float4(nr,nr,nr,1.0f);
    return float4(matAlbedo,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
