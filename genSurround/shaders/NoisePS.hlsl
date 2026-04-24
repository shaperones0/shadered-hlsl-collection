cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

float uSeed;

// value noise (tiled) R/G
float hash(float2 p, float2 period) {
    p = fmod(p, period);
    return frac(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float vnoise(float2 p, float2 period) {
    float2 i = floor(p);
    float2 f = frac(p);

    float a = hash(i, period);
    float b = hash(i + float2(1,0), period);
    float c = hash(i + float2(0,1), period);
    float d = hash(i + float2(1,1), period);

    float2 u = f * f * (3.0 - 2.0 * f);

    return lerp(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

float fbm(float2 p, float2 period) {
    float v = 0.0;
    float a = 0.5;

    for (int i = 0; i < 4; i++) {
        v += vnoise(p, period) * a;
        p *= 2.0;
        period *= 2.0;
        a *= 0.5;
    }

    return v;
}

// simplex noise (tiled) R/G
float greaterThan(float x, float y) { return step(y, x); }
float2 greaterThan(float2 x, float2 y) { return step(y, x); }
float3 greaterThan(float3 x, float3 y) { return step(y, x); }
float4 greaterThan(float4 x, float4 y) { return step(y, x); }

float mod(in float x, in float y) { return x - y * floor(x / y); }
float2 mod(in float2 x, in float2 y) { return x - y * floor(x / y); }
float3 mod(in float3 x, in float3 y) { return x - y * floor(x / y); }
float4 mod(in float4 x, in float4 y) { return x - y * floor(x / y); }

float psrdnoise(float2 x, float2 period, float alpha, out float2 gradient) {

	// Transform to simplex space (axis-aligned hexagonal grid)
	float2 uv = float2(x.x + x.y*0.5, x.y);

	// Determine which simplex we're in, with i0 being the "base"
	float2 i0 = floor(uv);
	float2 f0 = frac(uv);
	// o1 is the offset in simplex space to the second corner
	float cmp = step(f0.y, f0.x);
	float2 o1 = float2(cmp, 1.0-cmp);

	// Enumerate the remaining simplex corners
	float2 i1 = i0 + o1;
	float2 i2 = i0 + float2(1.0, 1.0);

	// Transform corners back to texture space
	float2 v0 = float2(i0.x - i0.y * 0.5, i0.y);
	float2 v1 = float2(v0.x + o1.x - o1.y * 0.5, v0.y + o1.y);
	float2 v2 = float2(v0.x + 0.5, v0.y + 1.0);

	// Compute vectors from v to each of the simplex corners
	float2 x0 = x - v0;
	float2 x1 = x - v1;
	float2 x2 = x - v2;

	float3 iu = float3(0.0, 0.0, 0.0);
    float3 iv = float3(0.0, 0.0, 0.0);
	float3 xw = float3(0.0, 0.0, 0.0);
    float3 yw = float3(0.0, 0.0, 0.0);

	// Wrap to periods, if desired
	if( any(greaterThan(period, float2(0.0, 0.0))) ) {
		xw = float3(v0.x, v1.x, v2.x);
		yw = float3(v0.y, v1.y, v2.y);
		if(period.x > 0.0)
			xw = mod(float3(v0.x, v1.x, v2.x), period.x);
		if(period.y > 0.0)
			yw = mod(float3(v0.y, v1.y, v2.y), period.y);
		// Transform back to simplex space and fix rounding errors
		iu = floor(xw + 0.5*yw + 0.5);
		iv = floor(yw + 0.5);
	} else { // Shortcut if neither x nor y periods are specified
		iu = float3(i0.x, i1.x, i2.x);
		iv = float3(i0.y, i1.y, i2.y);
	}

	// Compute one pseudo-random hash value for each corner
	float3 hash = mod(iu, 289.0);
	hash = mod((hash*51.0 + 2.0)*hash + iv, 289.0);
	hash = mod((hash*34.0 + 10.0)*hash, 289.0);

	// Pick a pseudo-random angle and add the desired rotation
	float3 psi = hash * 0.07482 + alpha;
	float3 gx = cos(psi);
	float3 gy = sin(psi);

	// Reorganize for dot products below
	float2 g0 = float2(gx.x,gy.x);
	float2 g1 = float2(gx.y,gy.y);
	float2 g2 = float2(gx.z,gy.z);

	// Radial decay with distance from each simplex corner
	float3 w = 0.8 - float3(dot(x0, x0), dot(x1, x1), dot(x2, x2));
	w = max(w, 0.0);
	float3 w2 = w * w;
	float3 w4 = w2 * w2;

	// The value of the linear ramp from each of the corners
	float3 gdotx = float3(dot(g0, x0), dot(g1, x1), dot(g2, x2));

	// Multiply by the radial decay and sum up the noise value
	float n = dot(w4, gdotx);

	// Compute the first order partial derivatives
	float3 w3 = w2 * w;
	float3 dw = -8.0 * w3 * gdotx;
	float2 dn0 = w4.x * g0 + dw.x * x0;
	float2 dn1 = w4.y * g1 + dw.y * x1;
	float2 dn2 = w4.z * g2 + dw.z * x2;
	gradient = 10.9 * (dn0 + dn1 + dn2);

	// Scale the return value to fit nicely into the range [-1,1]
	return 10.9 * n;
}

//layered psrd noise
float psrdnoisel2D(float2 uv, float2 period) {
    float amplitude = 0.55;
    float frequency = 1.0;//0.5;
    float output = 0.0;
    float2 u;
    
    for (int i = 0; i < 5; i++) {
        output += 0.5*(1+psrdnoise(uv*frequency, period*frequency, 0.0, u))*amplitude;
        amplitude*=0.5; frequency*=2;
    }

    return saturate(output);
}


float sharpen(float x, float power) {
    x = saturate(x);
    return pow(x, power) / (pow(x, power) + pow(1 - x, power));
}

float4 mainC(float2 uv : SV_POSITION) : SV_TARGET {
    // Tileable coordinates
    //uv=frac(uv*2);
    float2 p = uv * 8.0;
    float2 period = float2(8.0);

    float r = fbm(p, period);
    float g = fbm(p * 2.0 + uSeed, period * 2.0);
    float b = sharpen(psrdnoisel2D(p, period) - 0.02, 2);
    
    return float4(r,g,b, 1);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
