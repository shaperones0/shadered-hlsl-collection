cbuffer vars : register(b0)
{
    float2 uResolution;
    float uTime;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

float hash(float2 p) {
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
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

float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return frac(sin(p) * 43758.5453);
}

// Exact border distance Voronoi — returns float3(border distance, nearest point offset)
float3 voronoi_border(float2 x) {
    //grid cell
    float2 ip = floor(x);
    //local position inside grid cell
    float2 fp = frac(x);

    // === Pass 1: Find nearest feature point ===
    //grid offset to cell of nearest point
    float2 mg;
    //closest feature point
    float2 mr;
    //closest distance
    float md = 8.0;

    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        // grid offset to current cell
        float2 g = float2(float(i), float(j));

        float density = vnoise(ip + g);
        int count = 1 + (int)(density * 20);

        for (int k = 0; k < count; k++) {
            // feature point inside current cell
            float2 o = hash2(ip + g + float(k));
            // vector from current position to that feature point
            //  g moves to neighbor cell,
            //  o offsets inside it,
            //  fp is local position
            float2 r = g + o - fp;
            float d = dot(r, r);

            if (d < md) {
                md = d;
                mr = r;
                mg = g;
            }
        }

    }

    // === Pass 2: Calculate shortest distance to border ===
    md = 8.0;

    for (int j = -2; j <= 2; j++)
    for (int i = -2; i <= 2; i++) {
        float2 g = mg + float2(float(i), float(j));
        float density = vnoise(ip + g);
        int count = 1 + (int)(density * 20);

        for (int k = 0; k < count; k++) {
            float2 o = hash2(ip + g + float(k));
            float2 r = g + o - fp;

            // Skip self
            if (dot(mr - r, mr - r) > 0.00001)
                // Distance to perpendicular bisector = midpoint projected onto direction vector
                md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
        }

    }

    return float3(md, mr);
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    float3 f1 = voronoi_border(uv*10);
    //float3 f2 = voronoi_border(uvw*10);

    float c;
    //c = max(1 - f1.x,1 - f2.x * 0.5);
    c = 1-f1;
    c = smoothstep(0.98,1,c);
    c = pow(c, 2);
    return float4(c,c,c,1.0f);
}

float4 main(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
