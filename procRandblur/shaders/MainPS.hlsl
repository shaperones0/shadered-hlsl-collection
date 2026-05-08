cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

Texture2D texBg : register(t0);
SamplerState smpBg : register(s0);
float uDistort;
float uWave;
float uDist;
#define ITER 3

static const float SQRT2 = 1.41421356237;

float4 tex(const int i, float2 uv) {
    if (i == 0) {
        return texBg.Sample(smpBg,uv);
    }
}

float2 hash23(float3 p3) {
	p3 = frac(p3 * float3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return frac((p3.xx+p3.yz)*p3.zy);
}

float2 randoff_square(float3 uv, float radius) {
    return (2*hash23(uv)-1)*radius;
}

float2 randoff_circle(float3 uv, float radius) {
    float2 hsh=hash23(uv);
    hsh.y*=6.2831853;
    return sqrt(hsh.x) * float2(cos(hsh.y), sin(hsh.y)) * radius;
}

float4 randblur(float2 uv) {
    float4 colother = float4(0.0, 0.0, 0.0, 0.0);
    for (int i = 0; i < ITER; i++) {
        float2 hsh=hash23(float3(uv*100,uTime*109+i*113));
        float2 uvo;
        //uvo = (2*hsh-1)*uRadius;    //square blur
        //radial
        hsh.y*=6.2831853;
        uvo = sqrt(hsh.x) * float2(cos(hsh.y), sin(hsh.y)) * uDistort;
        uvo = saturate(uv + uvo);
        
        colother += tex(0, uvo);
    }
    return colother/ITER;
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    //distort
    float2 uvo=randoff_circle(float3(uv*100,uTime*109), uDistort);
    
    float wave=sin(uv.y*50+uTime)*uWave;
    wave*=0.5-abs(uv.x-0.5);
    uvo.x+=wave;
    
    float4 col=tex(0, saturate(uv+uvo));
    //reduce alpha if displace too much
    col.a *= max(0, SQRT2-length(uvo)*uDist) / SQRT2;
    return col;    
}

float4 blend_normal(float4 src, float4 dest, float srcA) { return srcA * src + (1.0 - srcA) * dest; }

float4 main(float4 uv : SV_POSITION) : SV_TARGET {    
    float4 c=mainC(uv.xy / uResolution);
    return blend_normal(c,float4(0,uv.xy/uResolution/5,1),c.a);
}
