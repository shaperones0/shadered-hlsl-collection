cbuffer vars : register(b0)
{
    float2 uResolution;
    float uTime;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

float2 rotate(float2 v, float2 sc) {
    //sc = (sin, cos)
    return float2(
        v.x * sc.y - v.y * sc.x,
        v.x * sc.x + v.y * sc.y
    );
}

float2 rotate(float2 v, float angle) {
    float s = sin(angle);
    float c = cos(angle);

    return rotate(v, float2(s,c));
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //uvs are already normalized
    float2 uvR = rotate(uv-0.5f, uTime)*1.5;
    return float4(uvR.x,uvR.y,1.0f,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
