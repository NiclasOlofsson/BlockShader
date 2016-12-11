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


static const float4 watercolor = float4(1.0, 0.0, 0.0, 0.05); //the water color near you
static const float4 farwatercolor = float4(0.1, 0.3, 0.7, 0.9); //the water color in the distance...

// The width of the shadow. If you set it to 0.0 there will also be Sunlight in a cave :P
static const float shadowWidth = 0.880;
// NOTE: if you change the first, you must also change the third number! The 1.0 always(!) stays the same... 
// but if you want you can also try to change it xD. If yoj want to know what that does: that the width of the fade in!
static const float2 shadowFadeInWidth = float2(0.015, 1.0 / 0.015);

static const float3 torch_light = float3(0.5, 0.45, 0.05);

float randff(float n)
{
    return frac(cos(n) * 3782.288);
}

float smoothrand(float pos)
{
    float start = floor(pos);
    float smoothy = smoothstep(0.45, 0.55, frac(pos));
    //float smoothy = smoothstep(0.0, 1.0, frac(pos));
    return lerp(randff(start), randff(start + 1.0), smoothy);
}

float smoothrand2d(float horizont, float forward)
{
    float start = floor(forward);
    float smoothy = smoothstep(0.0, 1.0, frac(forward));
    return lerp(smoothrand(horizont + randff(start) * 1000.0), smoothrand(horizont + randff(start + 1.0) * 1000.0), smoothy);
}

float CheapWaterMap(float3 pos)
{
    pos.z += TIME * 0.5;
    float wave1 = smoothrand2d(pos.z + pos.z + pos.z, pos.x + pos.x + pos.x);
    float wave2 = sin(wave1) * 0.5 + 0.5;
    float interp = sin(TIME * 5.0 + pos.x + pos.z + pos.x + pos.z) * sin(pos.z) * 1.0;
    return lerp(wave1, wave2, interp);
}

float3 WaterNormalMap(float3 pos)
{
    float value = (CheapWaterMap(pos + float3(0.0, 0.0, 0.1)) - CheapWaterMap(pos)) * 1.0;
    return float3(0.0, 1.0, -value);
}

float cos_between_vecs(float3 v1, float3 v2)
{
    return (v1.x * v2.x + v1.y * v2.y + v1.z * v2.z) / length(v1) / length(v2);
}

float CloudMap1(float3 dir, float sizescale, float timescale)
{

    float timer = TIME * timescale;
    dir *= sizescale;
    dir.z += timer;
    float horizont = dir.x;
    float forward = dir.x + smoothrand2d((dir.x + dir.z) / 7.0, timer / 3.2) * 2.0;
    float rand1 = smoothrand2d(horizont / 2.0 + 2526.278, forward);

    return pow(rand1 * 1.1, 4.0);
}

float CloudMap2(float3 dir, float sizescale, float timescale)
{
    float timer = TIME * timescale;
    dir *= sizescale;
    dir.z += timer;
    float horizont = dir.x;
    float forward = dir.x;
    float rand1 = smoothrand2d(horizont, forward);
    float rand2 = smoothrand2d(horizont * 3.0 * 472.789, forward * 4.0);
    float rand3 = smoothrand2d(horizont * 4.0 + 637.29, forward * 4.0);

    return rand1 + (rand2 * 0.5 + rand3 * 0.75) * rand1;
}

float TypeMap(float3 dir, float timescale)
{
    return CloudMap1(dir, 0.1, 0.05 * timescale);
}

float4 Colorize(float cloud, float cloudmap, float darken, float3 cloudcolor, float3 color)
{
    float light = color.b;
    float3 border = float3(1.0, 1.0, 1.0);
    float4 result = float4(cloud, cloud, cloud, cloud);
    result.rgb = (cloudcolor - darken * 0.5 - cloudmap * darken * 0.2) * cloud * (light * 0.5 + 0.5) + border * (1.0 - cloud);
    return result;
}

float4 FullCloudMap(float3 dir, float timescale, float3 color)
{
    float gamma = TypeMap(dir, timescale);
    float darken = clamp((gamma - 0.0) * 1.6, 0.0, 1.0);
    float cloud2 = gamma;
    float cloud1 = 1.0 - cloud2;
    float cloudmap = CloudMap2(dir, 0.1, 0.5 * timescale);
    float rescloud = clamp(cloudmap + cloud2 * 2.0 - 1.0, 0.0, 1.0);
    float4 colorized = Colorize(rescloud, cloudmap, 0.0, float3(1.0, 1.0, 1.0), color);
    return colorized;
}

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

//#define REFLECT_FAR_WATER

static const float3 origin_water_normal = float3(0.0, 1.0, 0.0);

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
    #ifdef NEAR_WATER
    //diffuse = PSInput.color;
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

    //diffuse.rgb = PSInput.color;

    float4 uvs = TEXTURE_1.Sample(TextureSampler1, float2(PSInput.uv1.x * 0.65, PSInput.uv1.y));
    //diffuse = diffuse * uvs;

    float3 look_vector = PSInput.lookVector;

    float3 frag_water_normal = WaterNormalMap(PSInput.fragmentPosition);
    float3 water_normal = lerp(frag_water_normal, origin_water_normal, min(1.0, length(look_vector.xz) / max(50.0, abs(look_vector.y) * 4.0)));
    //water_normal = PSInput.normal;
    float view_angle = acos(abs(cos_between_vecs(look_vector, water_normal)));

	// Set the color of the water. Uncomment next line to 
	// have custom color
    //diffuse = float4(0.2, 0.5, 0.6, 0.0) * uvs;
    //if (PSInput.uv1.y >= 0.5)
    {
		// If bad weather, then this applies. Should probably be extended to deal with
		// thunder storms too. Should probably check the WEATHER define instead of fog.
		//if (FOG_CONTROL.x < 0.55 && FOG_CONTROL.x > 0.1)
        {
            //diffuse = lerp(float4(1, 1, 1, 1), diffuse, clamp(FOG_CONTROL.x + 0.5, 0, 1));
        }
    }

    float3 reflected_dir = normalize(reflect(look_vector, water_normal));
    float3 reflected_pos = reflected_dir * 100.0 / reflected_dir.y + look_vector;

	// Uncomment to enable cloud reflections in water. Cool effect,
	// but not so good looking.
    float4 cloud = FullCloudMap(PositionTransform(reflected_pos * 2.3, 500.0), 0.3, 0.3);
    //diffuse = lerp(diffuse, diffuse * float4(1.1, 1.1, 1.1, 1), (cloud.a * saturate(PSInput.uv1.y)));

    //diffuse.a = pow(view_angle / 3.0, clamp(PSInput.uv1.y, 0, 1));
    //diffuse.a = pow(view_angle / 3.0, 1.4);

    float4 suncolor = GetSunColor(reflected_pos * 2.3, uvs.r) * 3;
    diffuse += (suncolor * suncolor.a) * clamp(FOG_CONTROL.x - 0.50, 0, 1);

#ifndef NEAR_WATER
	}
#endif
#endif
    {
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
            float3 shadowColor = diffuse.rgb * shadowStrenght;
            diffuse.rgb = lerp(shadowColor, diffuse.rgb, 1 - fogFactor);
        }

        // The following can be used in order to detect if you are looking at the sun
        // Think: Flairs and water reflections...
        // float strength = (FOG_COLOR.r + FOG_COLOR.g + FOG_COLOR.b) / 3;

        if (PSInput.color.a < s && PSInput.uv1.r == 0 && PSInput.color.a > 0.0)
        {
            shadowStrenght = pow(PSInput.color.a, 1);
			// fade edges
            if (PSInput.color.a >= s - t)
            {
                float fadeIn = (PSInput.color.a - (s - t)) * 1 / t;
                shadowStrenght = lerp(shadowStrenght, 1.0, saturate(fadeIn));
            }
            float3 shadowColor = diffuse.rgb * shadowStrenght;
            diffuse.rgb = lerp(shadowColor, diffuse.rgb, 1 - fogFactor);
        }
    }

    #ifdef GURUN
    #endif

	// FINALLY SET IT
    PSOutput.color = diffuse;

#ifdef VR_MODE
	// On Rift, the transition from 0 brightness to the lowest 8 bit value is abrupt, so clamp to 
	// the lowest 8 bit value.
	PSOutput.color = max(PSOutput.color, 1 / 255.0f);
#endif

#endif // BYPASS_PIXEL_SHADER
}

