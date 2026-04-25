cbuffer vars : register(b0)
{
    float2 uResolution;
    float uTime;
};

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    float c = sin(uTime)*0.5+0.5;
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
