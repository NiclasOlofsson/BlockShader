#if defined(__INTELLISENSE__)
	#include ".\..\..\BlockShader\Includes\ShaderConstants.fxh"
	#include ".\..\..\BlockShader\Includes\Util.fxh"
#define TEXEL_AA
#define TEXEL_AA_FEATURE
#define VERSION 0xa000
#define NEAR_WATER
#define FOG
#define FANCY
#define ALPHA_TEST
#define USE_ALPHA_TEST true
#define BLEND
#else
#include "ShaderConstants.fxh"
#include "util.fxh"
#endif

float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 11.2;

float3 Uncharted2Tonemap(float3 x)
{
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

struct PS_Input
{
    float4 position : SV_Position;

#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 color : COLOR;
    snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
    snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif

#ifdef FOG
    float4 fogColor : FOG_COLOR;
#endif
};

struct PS_Output
{
    float4 color : SV_Target;
};

ROOT_SIGNATURE
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
#ifdef BYPASS_PIXEL_SHADER
    PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
    return;
#else

#if USE_TEXEL_AA
    float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv0);
#else
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0f;
#endif

#if USE_ALPHA_TEST
#ifdef ALPHA_TO_COVERAGE
#define ALPHA_THRESHOLD 0.05
#else
#define ALPHA_THRESHOLD 0.5
#endif
    if (diffuse.a < ALPHA_THRESHOLD)
        discard;
#endif

#if defined(BLEND)
    diffuse.a *= PSInput.color.a;
#endif

#if !defined(ALWAYS_LIT)
    diffuse = diffuse * TEXTURE_1.Sample(TextureSampler1, PSInput.uv1);
#endif

#ifndef SEASONS
#if !USE_ALPHA_TEST && !defined(BLEND)
		diffuse.a = PSInput.color.a;
#endif	

    diffuse.rgb *= PSInput.color.rgb;
#else
	float2 uv = PSInput.color.xy;
	diffuse.rgb *= lerp(1.0f, TEXTURE_2.Sample(TextureSampler2, uv).rgb*2.0f, PSInput.color.b);
	diffuse.rgb *= PSInput.color.aaa;
	diffuse.a = 1.0f;
#endif

#ifdef FOG
    diffuse.rgb = lerp(diffuse.rgb, PSInput.fogColor.rgb, PSInput.fogColor.a);
#endif

	{

		// Shadows

        float3 texColor = diffuse * 1.5; // Hardcoded Exposure Adjustment

        float ExposureBias = 2.0f;
        float3 curr = Uncharted2Tonemap(ExposureBias * texColor);

        float3 whiteScale = 1.0f / Uncharted2Tonemap(W);
        float3 color = curr * whiteScale;

        float3 retColor = pow(color, 1 / 2.2);

        // Uncommment next line for tonemapping.
        //diffuse.rgb = texColor;

        // INFO: Stuff to play around with
        // PSInput.uv0.r highlights sand?
        // PSInput.uv0.g nothing?
        // PSInput.uv1.r highlight fire/lava
        // PSInput.uv1.g highlight shadow
        // PSInput.color.w = amount of sun it gets

        float s = 0.921; // cutoff for shadows
        float t = 0.005; // Width of the edge fade

        float shadowStrenght = 0.0;
        float fadeIn = 0.0;
        float fogFactor = (FOG_COLOR.r + FOG_COLOR.g + FOG_COLOR.b) / 3;

        if (PSInput.uv1.y < s && PSInput.uv1.r == 0 && PSInput.color.a > 0.0)
        {
            shadowStrenght = pow(PSInput.uv1.y, 4);

			// fade edges
            if (PSInput.uv1.y >= s - t)
            {
                float fadeIn = (PSInput.uv1.y - (s - t)) * 1 / t;
                shadowStrenght = lerp(shadowStrenght, 1.0, saturate(fadeIn));
            }
            shadowStrenght = clamp(shadowStrenght, 0.3, 1.0);
            float3 shadowColor = diffuse.rgb * shadowStrenght;
            diffuse.rgb = lerp(shadowColor, diffuse.rgb, 1 - fogFactor);
        }

        if (PSInput.color.a < s && PSInput.uv1.r == 0 && PSInput.color.a > 0.0)
        {
            shadowStrenght = pow(PSInput.color.a, 1);
			// fade edges
            if (PSInput.color.a >= s - t)
            {
                float fadeIn = (PSInput.color.a - (s - t)) * 1 / t;
                shadowStrenght = lerp(shadowStrenght, 1.0, saturate(fadeIn));
            }
            shadowStrenght = clamp(shadowStrenght, 0.3, 1.0);
            float3 shadowColor = diffuse.rgb * shadowStrenght;
            diffuse.rgb = lerp(shadowColor, diffuse.rgb, 1 - fogFactor);
        }
        
        // The following can be used in order to detect if you are looking at the sun
        // Think: Flairs and water reflections...
        // float strength = (FOG_COLOR.r + FOG_COLOR.g + FOG_COLOR.b) / 3;
    }

    PSOutput.color = diffuse;

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to 
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}