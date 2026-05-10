cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texDots : register(t0);
SamplerState smpDots : register(s0);

Texture2D texNoise : register(t1);
SamplerState smpNoise : register(s1);

Texture2D texBlocks : register(t2);
SamplerState smpBlocks : register(s2);


float uThreshold;
float uP;

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texDots.Sample(smpDots,uv);
    }
    else if (i==1) {
        return texNoise.Sample(smpNoise,uv);
    }
    else if (i==2) {
        return texBlocks.Sample(smpBlocks,uv);
    }
}


// maf

//bring value away from 0.5 and closer to 0 and 1
float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float lerp2(float fromA, float fromB, float toA, float toB, float value) {
    return ((value-fromA)/(fromB-fromA))*(toB-toA)+toA;
}

//the /\/\/\ polyline
float fold(float val, int n) {
    return 1 - abs(1 - 2*frac(val * n));
}

// hash

float hash(float2 p) {
    p = frac(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return frac(p.x * p.y);
}

#define RANDOM_SCALE float4(443.897, 441.423, 0.0973, 0.1099)
float2 hash2(float p) {
    float3 p3 = frac(float3(p, p, p) * RANDOM_SCALE.xyz);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz) * p3.zy);
}

// noises

//smooth hash over time
float hashSmooth(float2 uv, float time) {
    float z = time;
    float iz = floor(z);
    float f = frac(z);
    f = sharpen(f, 1.2);

    // 3-tap weights
    float w0 = 0.5 * (1.0 - f) * (1.0 - f);
    float w1 = 0.75 - (f - 0.5)*(f - 0.5);
    float w2 = 0.5 * f * f;

    float2 base = uv;

    float n0 = hash(base + hash2(iz - 1)).r;
    float n1 = hash(base + hash2(iz)).r;
    float n2 = hash(base + hash2(iz + 1)).r;

    float result = n0*w0 + n1*w1 + n2*w2;

    return result;
}

//surround the center with tentacle like thingies
float nsSurround(float2 uv) {
    //square uv
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

    float2 flow = float2(0.05, 0.03) * uTime;
    float2 warp = tex(1, uv*2.0 + flow).rg - 0.5;

    float ns;
    ns = tex(1, uv*0.15 + warp*0.2/20).b;
    ns = 1-fold(saturate(ns),3);

    //make the center dark
    float2 d = uv - 0.5f;
    float dist = length(d);
    dist=pow(dist,1.5);

    //1d radial noise to jostle the border
    float2 d2 = float2(
        d.x * 0.707 - d.y * 0.707,
        d.x * 0.707 + d.y * 0.707
    );
    float angle = sign(d2.y) * (1 - d2.x / (abs(d2.x) + abs(d2.y) + 1e-5));
    float n1;
    n1 = tex(1, float2(angle * 1 * 0.1, uTime * 0.02)).b;
    n1 = sharpen(n1+0.13,6);

    //apply the dark center
    float dark = (1.0 - dist * uP * (n1 * lerp(0,0.2,saturate(uP-1)) + 1));
    ns=saturate(ns-dark);

    return ns;
    //make uniformly darker spots
    ns=smoothstep(0.5,1,ns);
    //ns=round(ns);
}

// blocks

bool isLargeAnchor(int2 cell) {
    float r = hash(cell);
    if (r >= uThreshold)
        return false;
    //texture contains dots such as no dots touch
    float2 size = floor(uResolution / 16);
    return tex(0, cell / size+0.1).r>0.5;
}

struct BlockInfo {
    float2 blockUV;

    //pixel-space origin
    float2 blockOrigin;

    //16 or 32
    float  blockSize;
};

BlockInfo getBlockInfo(float2 fragCoord) {
    BlockInfo o;
    int2 cell = (int2)floor(fragCoord / 16.0);
    int2 candidates[4];

    candidates[0] = cell;
    candidates[1] = cell + int2(-1,  0);
    candidates[2] = cell + int2( 0, -1);
    candidates[3] = cell + int2(-1, -1);

    bool foundLarge = false;
    int2 largeAnchor = cell;

    [unroll]
    for (int i = 0; i < 4; i++) {
        int2 a = candidates[i];

        if (!isLargeAnchor(a))
            continue;

        bool inside =
            cell.x >= a.x &&
            cell.x <  a.x + 2 &&
            cell.y >= a.y &&
            cell.y <  a.y + 2;

        if (inside) {
            foundLarge = true;
            largeAnchor = a;
            break;
        }
    }

    if (foundLarge) {
        float2 origin = float2(largeAnchor) * 16.0;

        o.blockOrigin = origin;
        o.blockSize   = 32.0;
        o.blockUV     = (fragCoord - origin) / 32.0;
    }
    else {

        float2 origin = floor(fragCoord / 16.0) * 16.0;

        o.blockOrigin = origin;
        o.blockSize   = 16.0;
        o.blockUV     = (fragCoord - origin) / 16.0;
    }

    return o;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    BlockInfo b = getBlockInfo(uv*uResolution);

    float2 buv = b.blockUV;
    float2 bo = b.blockOrigin / uResolution;

    float surround = nsSurround(bo);
    // if (surround<0.2) discard;

    float3 color;

    //texture
    color = tex(2, float2(
        buv.x/5 + floor(hashSmooth(bo, uTime)*5)/5,
        buv.y
    )).rgb;

    //whitenoise
    color += (2 * hashSmooth(uv*1007,uTime*3) - 1)*0.3;

    //outline
    float edge =
        smoothstep(0,0.05, buv.x) *
        smoothstep(0,0.05, buv.y) *
        smoothstep(buv.x, 0.95,1) *
        smoothstep(buv.y, 0.95,1);
    color *= lerp2(0,1,0.5,1,edge);

    //float surround = nsSurround(bo);
    float vis = step(0.2, surround);
    color *= vis;
    //color = surround;
    //color = nsSurround(uv);

    return float4(color, vis);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
