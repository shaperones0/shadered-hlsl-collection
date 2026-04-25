cbuffer vars : register(b0)
{
    float2 uResolution;
    float uTime;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

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

float pnoiseL(in float3 v, in float3 rep) {
    float amplitude = 0.5;
    float frequency = 8.0;
    float output = 0.0;
    static const int octaves=4;
    for (int i = 0; i < octaves; i++)
    {
        output += pnoise(v * frequency, rep) * amplitude;
        amplitude *= 0.5;
        frequency *= 2.1;
    }

    return clamp(output, 0.0, 1.0);
}

float fold(float val, float n) {
    val = frac(val * n);
    return 1 - abs(1 - 2*val);
}

float genBack(float2 uv) {
    float nw=worley(float3(uv*float2 (4.0,3.7),uTime));
    //nw=fold(nw,1);
    nw=pow(1-nw*0.5,2);
    //nw=fold(nw,1);
    float np=pnoiseL(float3(uv*1,uTime/10),float3(10.0));
    np = np*0.3+0.7;
    return nw*np;
}

float genVeins(float2 uv) {
    float np=pnoise(float3(uv*15,10.1),float3(20.0));
    np=fold(np,1);
    np=pow(np,5);
    np=smoothstep(0.6,0.9,np);
    return round(np);
}

float genVeins2(float2 uv) {
    float np=pnoiseL(float3(uv*10,uTime/10),float3(20.0));
    np=fold(np,1);
    np=pow(np,5);
    np=smoothstep(0.6,0.9,np);
    return np;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized

    //wapr uv
    float p1 = pnoise(float3(uv*9,uTime*0.3), float3(10.0) );
    float p2 = pnoise(float3(uv*7,uTime*0.2), float3(10.0) );
    float2 warp = float2(p1,p2);
    float2 uvw = uv + warp * 0.15;

    float c=genBack(uvw);
    c=c+genVeins(uvw)*0.3*c;
    //c=c+genVeins2(lerp(uv,uvw,0.5))*0.3*c;
    c=smoothstep(0.2,0.8,c);
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
