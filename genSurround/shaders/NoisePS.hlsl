cbuffer vars : register(b0) {
    float2 uResolution;
    float uTime;
};

//Texture2D tex : register(t0);
//SamplerState smp : register(s0);

float uSeed;

// value noise (tilable) R/G
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

    float2 u = f*f*(3.0-2.0*f);

    return lerp(a, b, u.x) +
           (c - a)*u.y*(1.0-u.x) +
           (d - b)*u.x*u.y;
}

float fbm(float2 p, float2 period) {
    float v = 0.0;
    float a = 0.5;

    v += vnoise(p, period) * a;
    p *= 2.0; period *= 2.0; a *= 0.5;

    v += vnoise(p, period) * a;
    p *= 2.0; period *= 2.0; a *= 0.5;

    v += vnoise(p, period) * a;
    p *= 2.0; period *= 2.0; a *= 0.5;

    v += vnoise(p, period) * a;

    return v;
}

//simplex noise B
float3 mod289(float3 x){return x-floor(x*(1./289.))*289.;}
float4 mod289(float4 x){return x-floor(x*(1./289.))*289.;}
float4 permute(float4 x){return mod289(((x*34.0)+1.0)*x);}
float4 taylorInvSqrt(float4 r){return 1.79284291400159-0.85373472095314*r;}

float snoise(float3 v){
    const float2 C=float2(1.0/6.0,1.0/3.0);

    float3 i=floor(v+dot(v,C.yyy));
    float3 x0=v-i+dot(i,C.xxx);

    float3 g=step(x0.yzx,x0.xyz);
    float3 l=1.0-g;
    float3 i1=min(g.xyz,l.zxy);
    float3 i2=max(g.xyz,l.zxy);

    float3 x1=x0-i1+C.xxx;
    float3 x2=x0-i2+C.yyy;
    float3 x3=x0-0.5;

    i=mod289(i);
    float4 p=permute(permute(permute(
        i.z+float4(0.0,i1.z,i2.z,1.0))
        +i.y+float4(0.0,i1.y,i2.y,1.0))
        +i.x+float4(0.0,i1.x,i2.x,1.0));

    float4 j=p-49.0*floor(p/49.0);
    float4 x_=floor(j/7.0);
    float4 y_=floor(j-7.0*x_);

    float4 x=(x_*2.0+0.5)/7.0-1.0;
    float4 y=(y_*2.0+0.5)/7.0-1.0;

    float4 h=1.0-abs(x)-abs(y);

    float4 b0=float4(x.xy,y.xy);
    float4 b1=float4(x.zw,y.zw);

    float4 s0=floor(b0)*2.0+1.0;
    float4 s1=floor(b1)*2.0+1.0;
    float4 sh=-step(h,0.0);

    float4 a0=b0.xzyw+s0.xzyw*sh.xxyy;
    float4 a1=b1.xzyw+s1.xzyw*sh.zzww;

    float3 g0=float3(a0.xy,h.x);
    float3 g1=float3(a0.zw,h.y);
    float3 g2=float3(a1.xy,h.z);
    float3 g3=float3(a1.zw,h.w);

    float4 norm=taylorInvSqrt(float4(dot(g0,g0),dot(g1,g1),dot(g2,g2),dot(g3,g3)));
    g0*=norm.x; g1*=norm.y; g2*=norm.z; g3*=norm.w;

    float4 m=max(0.6-float4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.0);
    m*=m; m*=m;

    float4 px=float4(dot(x0,g0),dot(x1,g1),dot(x2,g2),dot(x3,g3));
    return 42.0*dot(m,px);
}

float snoisel2D(float2 uv) {
    float amplitude = 0.25;
    float frequency = 0.5;
    float output = 0.0;
    float2 u;
    

    output += (2*snoise(float3(uv*frequency,0))+1)*amplitude;
    amplitude*=0.5; frequency*=2.1;

    output += (2*snoise(float3(uv*frequency,0))+1)*amplitude;
    amplitude*=0.5; frequency*=2.1;

    output += (2*snoise(float3(uv*frequency,0))+1)*amplitude;
    amplitude*=0.5; frequency*=2.1;

    output += (2*snoise(float3(uv*frequency,0))+1)*amplitude;
    amplitude*=0.5; frequency*=2.1;

    output += (2*snoise(float3(uv*frequency,0))+1)*amplitude;

    return saturate(output);
}

//simplex noise (tilable) B
//float4 mod289(float4 x){return x-floor(x*(1./289.))*289.;}
//float4 permute(float4 x){return mod289(((x*34.0)+1.0)*x);}
//float4 taylorInvSqrt(float4 r){return 1.79284291400159-0.85373472095314*r;}

float4 grad4(float j, float4 ip) {
    const float4 ones = float4(1.0, 1.0, 1.0, -1.0);
    float4 p, s;

    p.xyz = floor( frac (float3(j, j, j) * ip.xyz) * 7.0) * ip.z - 1.0;
    p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
    // GLSL: s = float4(lessThan(p, float4(0.0)));
    s = float4(1 - step(float4(0, 0, 0, 0), p));
    p.xyz = p.xyz + (s.xyz * 2.0 - 1.0) * s.www;

    return p;
}

float snoise4(in float4 v) {
    const float4  C = float4( 0.138196601125011,  // (5 - sqrt(5))/20  G4
                        0.276393202250021,  // 2 * G4
                        0.414589803375032,  // 3 * G4
                        -0.447213595499958); // -1 + 4 * G4

    // First corner
    float4 i  = floor(v + dot(v, float4(.309016994374947451, .309016994374947451, .309016994374947451, .309016994374947451)) ); // (sqrt(5) - 1)/4
    float4 x0 = v -   i + dot(i, C.xxxx);

    // Other corners

    // Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
    float4 i0;
    float3 isX = step( x0.yzw, x0.xxx );
    float3 isYZ = step( x0.zww, x0.yyz );
    //  i0.x = dot( isX, float3( 1.0 ) );
    i0.x = isX.x + isX.y + isX.z;
    i0.yzw = 1.0 - isX;
    //  i0.y += dot( isYZ.xy, float2( 1.0 ) );
    i0.y += isYZ.x + isYZ.y;
    i0.zw += 1.0 - isYZ.xy;
    i0.z += isYZ.z;
    i0.w += 1.0 - isYZ.z;

    // i0 now contains the unique values 0,1,2,3 in each channel
    float4 i3 = clamp( i0, 0.0, 1.0 );
    float4 i2 = clamp( i0-1.0, 0.0, 1.0 );
    float4 i1 = clamp( i0-2.0, 0.0, 1.0 );

    //  x0 = x0 - 0.0 + 0.0 * C.xxxx
    //  x1 = x0 - i1  + 1.0 * C.xxxx
    //  x2 = x0 - i2  + 2.0 * C.xxxx
    //  x3 = x0 - i3  + 3.0 * C.xxxx
    //  x4 = x0 - 1.0 + 4.0 * C.xxxx
    float4 x1 = x0 - i1 + C.xxxx;
    float4 x2 = x0 - i2 + C.yyyy;
    float4 x3 = x0 - i3 + C.zzzz;
    float4 x4 = x0 + C.wwww;

    // Permutations
    i = mod289(i);
    float j0 = permute( permute( permute( permute(i.w) + i.z) + i.y) + i.x);
    float4 j1 = permute( permute( permute( permute (
                i.w + float4(i1.w, i2.w, i3.w, 1.0 ))
            + i.z + float4(i1.z, i2.z, i3.z, 1.0 ))
            + i.y + float4(i1.y, i2.y, i3.y, 1.0 ))
            + i.x + float4(i1.x, i2.x, i3.x, 1.0 ));

    // Gradients: 7x7x6 points over a cube, mapped onto a 4-cross polytope
    // 7*7*6 = 294, which is close to the ring size 17*17 = 289.
    float4 ip = float4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;

    float4 p0 = grad4(j0,   ip);
    float4 p1 = grad4(j1.x, ip);
    float4 p2 = grad4(j1.y, ip);
    float4 p3 = grad4(j1.z, ip);
    float4 p4 = grad4(j1.w, ip);

    // Normalise gradients
    float4 norm = taylorInvSqrt(float4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;
    p4 *= taylorInvSqrt(dot(p4,p4));

    // Mix contributions from the five corners
    float3 m0 = max(0.6 - float3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), 0.0);
    float2 m1 = max(0.6 - float2(dot(x3,x3), dot(x4,x4)            ), 0.0);
    m0 = m0 * m0;
    m1 = m1 * m1;
    return 49.0 * ( dot(m0*m0, float3( dot( p0, x0 ), dot( p1, x1 ), dot( p2, x2 )))
                + dot(m1*m1, float2( dot( p3, x3 ), dot( p4, x4 ) ) ) ) ;
}


float2 wrapToCircle(float x) {
    float a = x * 6.2831853;
    return float2(cos(a), sin(a));
}

float snoisel2D_tile(float2 uv, float period) {
    float amplitude = 0.25;
    float frequency = 0.5;
    float output = 0.0;

    for (int i = 0; i < 5; i++) {

        float2 p = uv * frequency / period;

        float2 cx = wrapToCircle(p.x);
        float2 cy = wrapToCircle(p.y);

        float4 v = float4(cx, cy);

        output += (snoise4(v) * 2 + 1) * amplitude;

        amplitude *= 0.5;
        frequency *= 2.1;
    }

    return saturate(output);
}

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

float psrdnoisel2D(float2 uv, float2 period) {
    float amplitude = 0.55;
    float frequency = 1.0;//0.5;
    float output = 0.0;
    float2 u;
    
    output += 0.5*(1+psrdnoise(uv*frequency, period*frequency, 0.0, u))*amplitude;
    amplitude*=0.5; frequency*=2;

    output += 0.5*(1+psrdnoise(uv*frequency, period*frequency, 0.0, u))*amplitude;
    amplitude*=0.5; frequency*=2;

    output += 0.5*(1+psrdnoise(uv*frequency, period*frequency, 0.0, u))*amplitude;
    amplitude*=0.5; frequency*=2;

    output += 0.5*(1+psrdnoise(uv*frequency, period*frequency, 0.0, u))*amplitude;
    amplitude*=0.5; frequency*=2;

    output += 0.5*(1+psrdnoise(uv*frequency, period*frequency, 0.0, u))*amplitude;

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
    float b;
    //p = uv * 8.0 + uTime;
    b = sharpen(snoisel2D_tile(p, 8.0),1.3);
    float2 u;
    //b = (psrdnoise(p, float2(1.0), 0.0, u)+1)*0.5;
    b = psrdnoisel2D(p, period);
    b = 0;
    b += (psrdnoise(p, float2(8.0), 0.0, u)+1)*0.25;
    b += (psrdnoise(p * 2, float2(8.0*2), 0.0, u)+1)*0.125;
    b += (psrdnoise(p * 4, float2(8.0*4), 0.0, u)+1)*0.0625;
    b += (psrdnoise(p * 8, float2(8.0*8), 0.0, u)+1)*0.03125;
    b += (psrdnoise(p * 16, float2(8.0*16), 0.0, u)+1)*0.015625;
    b = psrdnoisel2D(p, period);
    //b += (psrdnoise(p / 2, float2(8.0/2), 0.0, u)+1)*0.125;
    //b += (psrdnoise(p / 4, float2(8.0/4), 0.0, u)+1)*0.0625;
    //b += (psrdnoise(p / 8, float2(8.0/8), 0.0, u)+1)*0.03125;
    //b += (psrdnoise(p / 16, float2(8.0/16), 0.0, u)+1)*0.015625;
    b = sharpen(b-0.02, 2);
    //b = snoisel2D(p*2);
    //return float4(g,g,g, 1);
    return float4(r,g,b, 1);
}

float4 mainShadered(float4 uv : SV_POSITION) : SV_TARGET {
    return mainC(uv.xy / uResolution);
}
