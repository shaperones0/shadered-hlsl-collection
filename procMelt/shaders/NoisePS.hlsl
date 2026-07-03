cbuffer vars : register(b0) {
    float2 uResolution;
};

float2 hash22(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)), dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * frac(sin(p) * 43758.5453);
}

float perlinTile(float2 p, float tileRes) {
    float2 i = floor(p);
    float2 f = frac(p);
    float2 u = f * f * (3.0 - 2.0 * f);

    float2 i00 = fmod(i, tileRes);
    float2 i10 = fmod(i + float2(1.0, 0.0), tileRes);
    float2 i01 = fmod(i + float2(0.0, 1.0), tileRes);
    float2 i11 = fmod(i + float2(1.0, 1.0), tileRes);

    return lerp(
        lerp(dot(hash22(i00), f - float2(0.0, 0.0)), 
             dot(hash22(i10), f - float2(1.0, 0.0)), u.x),
        lerp(dot(hash22(i01), f - float2(0.0, 1.0)), 
             dot(hash22(i11), f - float2(1.0, 1.0)), u.x), u.y
    );
}

float fbmTile(float2 p, float tileRes) {
    float f = perlinTile(p, tileRes) * 0.5 
            + perlinTile(p * 2.0, tileRes * 2.0) * 0.25 
            + perlinTile(p * 4.0, tileRes * 4.0) * 0.125;
            
    return f * 0.5 + 0.5;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    float tileRes = 8.0; 
    float2 scaledUV = uv * tileRes;

    float r = fbmTile(scaledUV, tileRes);
    float g = perlinTile(scaledUV + float2(133.0, 277.0), tileRes) * 0.5 + 0.5;
    float b = perlinTile(scaledUV + float2(311.0, 499.0), tileRes) * 0.5 + 0.5;
    return float4(r, g, b, 1.0);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
