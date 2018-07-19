#if defined(__INTELLISENSE__)
#define TEXEL_AA
#define TEXEL_AA_FEATURE
#define VERSION  0xa000
#define NEAR_WATER
#define FOG
#define ALLOW_FADE
#define FANCY
#define ALPHA_TEST
#define SWAY
#define ROOT_SIGNATURE 
#else
#endif

#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE) || (VERSION < 0xa000 /*D3D_FEATURE_LEVEL_10_0*/) 
#define USE_TEXEL_AA 0
#else
#define USE_TEXEL_AA 1
#endif

#ifdef ALPHA_TEST
#define USE_ALPHA_TEST 1
#else
#define USE_ALPHA_TEST 0
#endif

#if USE_TEXEL_AA

static const float TEXEL_AA_ALPHA_BIAS = 0.125f;
static const float TEXEL_AA_EPSILON = 0.03125f;

static const float TEXEL_AA_LOD_MIN = -0.5f;
static const float TEXEL_AA_LOD_MAX = 0.0f;

float4 texture2D_AA(in Texture2D source, in sampler bilinearSampler, in float2 originalUV) {

	const float2 dUV_dX = ddx(originalUV) * TEXTURE_DIMENSIONS.xy;
	const float2 dUV_dY = ddy(originalUV) * TEXTURE_DIMENSIONS.xy;

	const float2 delU = float2(dUV_dX.x, dUV_dY.x);
	const float2 delV = float2(dUV_dX.y, dUV_dY.y);

	const float2 gradientMagnitudes = float2(length(delU), length(delV));

	const float2 fractionalTexel = frac(originalUV * TEXTURE_DIMENSIONS.xy);
	const float2 integralTexel = floor(originalUV * TEXTURE_DIMENSIONS.xy);

	const float2 scalar = max(1.0f / max(gradientMagnitudes, TEXEL_AA_EPSILON), 1.0f);

	const float2 adjustedFractionalTexel = clamp(fractionalTexel * scalar, 0.0f, 0.5f) + clamp(fractionalTexel * scalar - (scalar - 0.5f), 0.0f, 0.5f);
	const float2 adjustedUV = (adjustedFractionalTexel + integralTexel) / TEXTURE_DIMENSIONS.xy;

	const float lod = source.CalculateLevelOfDetailUnclamped(bilinearSampler, originalUV);
	const float t = smoothstep(TEXEL_AA_LOD_MIN, TEXEL_AA_LOD_MAX, lod);
	const float4 sampledColor = source.Sample(bilinearSampler, lerp(adjustedUV, originalUV, t));

#if USE_ALPHA_TEST
		return float4(sampledColor.rgb, lerp(floor(pow(sampledColor.a + TEXEL_AA_ALPHA_BIAS, 2.0f)), sampledColor.a, t));
#else
		return sampledColor;
#endif
}

#endif // USE_TEXEL_AA

float MakeDepthLinear(float z, float n, float f, bool scaleZ)
{
	//Remaps z from [0, 1] to [-1, 1].
    if (scaleZ)
    {
        z = 2.f * z - 1.f;
    }
    return (2.f * n) / (f + n - z * (f - n));
}
