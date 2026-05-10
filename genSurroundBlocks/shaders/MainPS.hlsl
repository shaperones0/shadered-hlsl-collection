cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texDots : register(t0);
SamplerState smpDots : register(s0);
float uThreshold;

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texDots.Sample(smpDots,uv);
    }
}

float hash21(float2 p) {
    p = frac(p * float2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return frac(p.x * p.y);
}

bool isLargeAnchor(int2 cell) {
    float r = hash21(cell);
    if (r >= uThreshold)
        return false;
    //texture contains dot
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

    float3 color=float3(buv,1.0);

    //outline
    float edge =
        step(0.04, buv.x) *
        step(0.04, buv.y) *
        step(buv.x, 0.96) *
        step(buv.y, 0.96);

    color *= edge;


    return float4(color, 1.0);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
