cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

static const float uThreshold = 0.7;
float uR;

// maf

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

// hash

float hash(float2 p) {
    p = frac(p * 0.3183099 + float2(0.71, 0.113));
    p *= 17.0;
    return frac(p.x * p.y * (p.x + p.y));
}

#define RANDOM_SCALE float4(443.897, 441.423, 0.0973, 0.1099)
float2 hash2(float p) {
    float3 p3 = frac(float3(p, p, p) * RANDOM_SCALE.xyz);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.xx + p3.yz) * p3.zy);
}

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

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    float2 uvr = uv*uResolution;
    
    // Current 16x16 cell
    //int2 cell = (int2)floor(uvr / 16.0);
    int2 cell = (int2)uvr;
    float hshCell = hashSmooth(cell, uTime/10);
    
    int2 candidates[9];
    candidates[0] = cell + int2(-1, -1);
    candidates[1] = cell + int2( 0, -1);
    candidates[2] = cell + int2( 1, -1);
    
    candidates[3] = cell + int2(-1,  0);
    candidates[4] = cell + int2( 0,  0);
    candidates[5] = cell + int2( 1,  0);
    
    candidates[6] = cell + int2(-1,  1);
    candidates[7] = cell + int2( 0,  1);
    candidates[8] = cell + int2( 1,  1);
    
    int2 mxCell = int2(0,0);
    float mxHsh = -10;
    
    for (int i = 0; i < 9; i++) {
        float hsh;
        int2 cur = candidates[i];
        cur = fmod(cur, uResolution);    //prevent when wrapped
        if (i==4) {
            hsh = hshCell;
        } 
        else {
            hsh = hashSmooth(cur, uTime/10);
        }
        
        if (hsh > mxHsh) {
            mxHsh=hsh;
            mxCell=cur;
        }
    }
    
    float2 c2 = abs(mxCell-cell);
    
    float c = (cell.x==mxCell.x && cell.y==mxCell.y) ? 1.0 : 0.0;
    
    //chance to disappear
    float dist=length(cell/uResolution - float2(0.5));
    c*=step(uR,pow(dist,0.5)*hshCell);
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
