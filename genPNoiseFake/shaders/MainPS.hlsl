cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texN : register(t0);
SamplerState smpN : register(s0);
float uZoom;

float4 tex(const int i, float2 uv) {
    if (i==0) {
        return texN.Sample(smpN,uv);
    }
}

float lerp2(float fromA, float fromB, float toA, float toB, double value) {
    return ((value-fromA)/(fromB-fromA))*(toB-toA)+toA;
}

float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float3 sharpen(float3 x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
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

float fnoisev3(float3 uv) {
    float z = uv.z;
    float iz = floor(z);
    float f = frac(z);
    f = sharpen(f, 1.2);

    float w0 = 0.5 * (1.0 - f) * (1.0 - f);
    float w1 = 0.75 - (f - 0.5)*(f - 0.5);
    float w2 = 0.5 * f * f;

    float2 base = uv.xy;

    float n0 = tex(0, base + hash2(iz - 1)).g;
    float n1 = tex(0, base + hash2(iz)).g;
    float n2 = tex(0, base + hash2(iz + 1)).g;

    float result = n0*w0 + n1*w1 + n2*w2;

    return result;
}

float fnoisex(float3 uv) {
    float n = fnoisev3(uv);

    //mimic multi-octave
    n = (n - 0.5);
    n *= 1.3;
    n = n / (1.0 + abs(n));
    n = n * 0.5 + 0.5;

    return sharpen(n,2);
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //scale uv to square + zoom
    {
        float w=uResolution.x;
        float h=uResolution.y;
        float wReq=w;
        float hReq=h;
        if (w>h) {
            hReq=w;
        }
        else {
            wReq=h;
        }
        wReq*=(uZoom+1);
        hReq*=(uZoom+1);
        uv.x = lerp2(w-wReq, w+wReq, 0, 1, uv.x * 2*w);
        uv.y = lerp2(h-hReq, h+hReq, 0, 1, uv.y * 2*h);
    }
    float c = fnoisex(float3(uv*1.0, uTime));
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
