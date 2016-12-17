#if defined(__INTELLISENSE__)
	#include ".\..\..\BlockShader\Includes\ShaderConstants.fxh"
	#include ".\..\..\BlockShader\Includes\Util.fxh"
	#define TEXEL_AA
	#define TEXEL_AA_FEATURE
	#define VERSION  0xa000
	#define NEAR_WATER
	#define FOG
	#define FANCY
	#define ALPHA_TEST
	#define BLEND
#else
	#include "ShaderConstants.fxh"
	#include "Util.fxh"
#endif

struct PS_Input
{
    float4 position : SV_Position;
    float3 fragmentPosition : POSI;
    float3 lookVector : POSITION;
    float water_plane_flag : WATER_FLAG;
#ifndef BYPASS_PIXEL_SHADER
	lpfloat4 color : COLOR;
    snorm float2 uv0 : TEXCOORD_0_FB_MSAA;
    snorm float2 uv1 : TEXCOORD_1_FB_MSAA;
#endif

#ifdef NEAR_WATER
    float cameraDist : TEXCOORD_2;
    float3 normal : NORMAL;
#endif

#ifdef FOG
    float4 fogColor : FOG_COLOR;
#endif
};

struct PS_Output
{
    float4 color : SV_Target;
};

static const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange


float3 PositionTransform(float3 pos, float height)
{
    float dis = length(pos.xz);
    float ang = atan2(dis, height);
    return pos * cos(ang);
}

float4 GetSunColor(float3 pos, float day_flag)
{
    float3 sun_pos = float3(0.0, 100.0, -600.0);
    float white = clamp(abs(day_flag - 0.7) / 0.3 + 0.2, 0.0, 1.0);
    float4 sun_color = float4(1.0, white, white, 1.0);
    sun_color.a = pow(max(0.0, 1.0 - length(sun_pos.xz - pos.xz) / 160.0), 0.6);
    return sun_color;
}

static const float3 origin_water_normal = float3(0.0, 1.0, 0.0);

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


//
// MAIN
//
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
#ifdef BYPASS_PIXEL_SHADER
	PSOutput.color = float4(0.0f, 0.0f, 0.0f, 0.0f);
	return;
#else

#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE) || (VERSION < 0xa000 /*D3D_FEATURE_LEVEL_10_0*/) 
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv0);
#else
    float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv0);
    //float4 diffuse = PSInput.color;
    #ifdef NEAR_WATER
    {
        
        float3 relPos = (PSInput.fragmentPosition - VIEW_POS) * -1;
        float cameraDepth = length(relPos);
        float F = (cameraDepth / FAR_CHUNKS_DISTANCE);
        diffuse = lerp(PSInput.color, diffuse, F);
    }
    #endif
#endif

#ifdef SEASONS_FAR
	diffuse.a = 1.0f;
	PSInput.color.b = 1.0f;
#endif

#ifdef ALPHA_TEST
	//If we know that all the verts in a triangle will have the same alpha, we should cull there first.
#ifdef ALPHA_TO_COVERAGE
	float alphaThreshold = .05f;
#else
    float alphaThreshold = .5f;
#endif
    if (diffuse.a < alphaThreshold)
        discard;
#endif

    diffuse = diffuse * TEXTURE_1.Sample(TextureSampler1, PSInput.uv1);

#ifndef SEASONS

#if !defined(ALPHA_TEST) && !defined(BLEND)
	diffuse.a = PSInput.color.a;
#elif defined(BLEND)
    diffuse.a *= PSInput.color.a;

#ifdef NEAR_WATER
    float alphaFadeOut = saturate(PSInput.cameraDist.x);
    diffuse.a = lerp(diffuse.a, 1.0f, alphaFadeOut);
#endif

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

#if defined(NEAR_WATER) || defined(REFLECT_FAR_WATER)
#ifndef NEAR_WATER
	if (PSInput.water_plane_flag > 0.5) {
#endif

	// DO advanced water

    float4 uvs = TEXTURE_1.Sample(TextureSampler1, float2(PSInput.uv1.x * 0.65, PSInput.uv1.y));
    float4 white = float4(1, 1, 1, 1);
    //float3 sunPosition = float3(4675, 65 + 10, -2435);
    float3 sunPosition = float3(0, 1000 * uvs.r, -10000 * (1 - uvs.r)) + VIEW_POS;
    float3 sun = normalize(PSInput.fragmentPosition - sunPosition); // From sun to pixel

    float3 lightDirection = normalize(sun);

    //float3 normal = normalize(float3(0, 1, 0));
    float3 normal = normalize(PSInput.normal);
    
    float4 diffuseTerm = saturate(dot(lightDirection, normal));
    float4 diffuseLight = diffuseTerm * white;

    float3 cameraDirection = normalize(VIEW_POS - PSInput.fragmentPosition); // From pixel to eye
								
    // Blinn-Phong
    float3 halfVector = normalize(-lightDirection + cameraDirection);
    float3 specularTerm = pow(saturate(dot(normal, halfVector)), 15);
 
    // Phong
    //float3 reflectionVector = reflect(lightDirection, normal);
    //float3 specularTerm = pow(saturate(dot(reflectionVector, cameraDirection)), 15);

    float intensity = clamp(pow(FOG_CONTROL.x * 10, 4) / 10, 0, 1) - 0.55;
    diffuse.rgb += FOG_COLOR.rgb * intensity * specularTerm;

    // Adjust for: more specular, less transparanecy
    float alpha = lerp(0.8, 1.0, specularTerm);

    float cameraDepth = length(-(PSInput.fragmentPosition - VIEW_POS));
    float F = (cameraDepth / FAR_CHUNKS_DISTANCE);

    diffuse.a *= lerp(alpha, 1, F);

    halfVector = normalize(lightDirection + cameraDirection);
    specularTerm = pow(saturate(dot(normal, halfVector)), 15);

    intensity = 1.0;
    //diffuse.rgb -= intensity * specularTerm;

    // If bad weather, then this applies. Should probably be extended to deal with
    // thunder storms too. Should probably check the WEATHER define instead of fog.
    if (FOG_CONTROL.x < 0.55 && FOG_CONTROL.x > 0.1)
    {
        //diffuse = lerp(float4(1, 1, 1, 1), diffuse, clamp(FOG_CONTROL.x + 0.5, 0, 1));
        diffuse = lerp(FOG_COLOR, diffuse, clamp(FOG_CONTROL.x + 0.5, 0, 1));
    }


    // TESTS:
    float3 look_vector = VIEW_POS - PSInput.fragmentPosition; // camera relative to target
    //look_vector = VIEW_POS; // world coordinates
    //look_vector = PSInput.fragmentPosition; // world coordinates
    //look_vector = PSInput.fragmentPosition - VIEW_POS; // Relative to camera
    //if (look_vector.x > 4640 && look_vector.x < 4700)
    //if (look_vector.x > 0 && look_vector.x < 100)
    //{
    //    diffuse.rgb = float3(1, 0, 0);
    //}

#ifndef NEAR_WATER
	}
#endif
#endif
    {

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

    //bool needYReset = frac(PSInput.fragmentPosition.y) > 0.887 && frac(PSInput.fragmentPosition.y) <= 1.0;
    //if (needYReset)
    //{
    //    diffuse.a = 0.3;
    //}

    //needYReset = frac(PSInput.fragmentPosition.y) >= 0.0 && frac(PSInput.fragmentPosition.y) < 0.12;
    //if (needYReset)
    //{
    //    diffuse.rgb = 0.4;
    //}

	// FINALLY SET IT
    PSOutput.color = diffuse;

#ifdef SWAY
#endif

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to 
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}

