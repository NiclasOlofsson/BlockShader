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
#else
	#include "ShaderConstants.fxh"
	#include "Util.fxh"
#endif

struct VS_Input {
	float3 position : POSITION;
	float4 color : COLOR;
	float2 uv0 : TEXCOORD_0;
	float2 uv1 : TEXCOORD_1;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input {
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
#endif

#ifdef FOG
	float4 fogColor : FOG_COLOR;
#endif
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


static const float rA = 1.0;
static const float rB = 1.0;
static const float3 UNIT_Y = float3(0, 1, 0);
static const float DIST_DESATURATION = 56.0 / 255.0; //WARNING this value is also hardcoded in the water color, don'tchange

void main(in VS_Input VSInput, out PS_Input PSInput) {

#ifndef BYPASS_PIXEL_SHADER
	PSInput.uv0 = VSInput.uv0;
	PSInput.uv1 = VSInput.uv1;
	PSInput.color = VSInput.color;
#endif

#ifdef AS_ENTITY_RENDERER
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul(WORLDVIEWPROJ_STEREO[i], float4(VSInput.position, 1));
	PSInput.instanceID = i;
#else
	PSInput.position = mul(WORLDVIEWPROJ, float4(VSInput.position, 1));
#endif
	float3 worldPos = PSInput.position;
#else
	float3 worldPos = (VSInput.position.xyz * CHUNK_ORIGIN_AND_SCALE.w) + CHUNK_ORIGIN_AND_SCALE.xyz;

	// Transform to view space before projection instead of all at once to avoid floating point errors
	// Not required for entities because they are already offset by camera translation before rendering
	// World position here is calculated above and can get huge
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;

	PSInput.position = mul(WORLDVIEW_STEREO[i], float4(worldPos, 1));
	PSInput.position = mul(PROJ_STEREO[i], PSInput.position);

	PSInput.instanceID = i;
#else
	PSInput.position = mul(WORLDVIEW, float4(worldPos, 1));
	PSInput.position = mul(PROJ, PSInput.position);
#endif
#endif

#ifdef ALPHA_TEST
	// Moving plants
	float3 pp = worldPos;
	if (PSInput.color.g + PSInput.color.g > PSInput.color.r + PSInput.color.b) {
		PSInput.position.x += sin(TIME * 4.0 + pp.x + pp.z + pp.x + pp.z + pp.y) * sin(pp.z) * 0.02;
		if (FOG_CONTROL.x < 0.55 && FOG_CONTROL.x > 0.1) {
			PSInput.position.x += sin(TIME * 6.0 + pp.x + pp.z + pp.x + pp.z + pp.y) * sin(pp.x) * 0.03;
		}
	}
#endif

#ifndef BYPASS_PIXEL_SHADER
	if (frac(PSInput.position.y) > 0.875 && frac(PSInput.position.y) < 0.90625 && VSInput.uv0.y > 0.5) {
		PSInput.water_plane_flag = 1.0;
	}
	else {
		PSInput.water_plane_flag = 0.0;
	}
#endif

	///// find distance from the camera

#if defined(FOG) || defined(NEAR_WATER)
#ifdef FANCY
	float3 relPos = -worldPos;
	float cameraDepth = length(relPos);
#ifdef NEAR_WATER
	PSInput.cameraDist = cameraDepth / FAR_CHUNKS_DISTANCE;
#endif
#else
	float cameraDepth = PSInput.position.z;
#ifdef NEAR_WATER
	float3 relPos = -worldPos;
	float cameraDist = length(relPos);
	PSInput.cameraDist = cameraDist / FAR_CHUNKS_DISTANCE;
#endif
#endif
#endif

	///// apply fog

#ifdef FOG
	float len = cameraDepth / RENDER_DISTANCE;
	float lenb = cameraDepth / RENDER_DISTANCE;
	float lenc = cameraDepth / RENDER_DISTANCE*4.0;

#ifdef ALLOW_FADE
	len += CURRENT_COLOR.r;
	lenb += CURRENT_COLOR.r;
	lenc += CURRENT_COLOR.r;
#endif

	PSInput.fogColor.rgb = FOG_COLOR.rgb;
	PSInput.fogColor.a = clamp((len - FOG_CONTROL.x) / (FOG_CONTROL.y - FOG_CONTROL.x), 0.0, 1.0);

	//if (FOG_COLOR.r > 0.15 && FOG_COLOR.g > 0.15) {
	//	if (FOG_CONTROL.x < 0.55 && FOG_CONTROL.x > 0.1) {
	//		PSInput.fogColor.a = clamp((len - FOG_CONTROL.x), 0.0, 1.0);
	//	}
	//}

	//if (FOG_CONTROL.x < 0.15) {
	//	PSInput.fogColor.a *= clamp((lenc - FOG_CONTROL.x), 0.0, 0.3);
	//	PSInput.fogColor.rgb /= FOG_COLOR.rgb;
	//	PSInput.fogColor.rgb *= float3(0.1, 0.1, 0.3);
	//}
	//else {
	//	PSInput.fogColor.a *= clamp((lenc - FOG_CONTROL.x), 0.0, 1.0);
	//	PSInput.fogColor.rgb /= FOG_COLOR.rgb;
	//	PSInput.fogColor.rgb *= float3(0.1, 0.1, 1.0);
	//}


#endif

	///// water magic
#ifdef NEAR_WATER
#ifdef FANCY  /////enhance water
	float F = dot(normalize(relPos), UNIT_Y);
	F = 1.0 - max(F, 0.1);
	F = 1.0 - lerp(F*F*F*F, 1.0, min(1.0, cameraDepth / FAR_CHUNKS_DISTANCE));

	PSInput.color.rg -= float2(float(F * DIST_DESATURATION).xx);

	float4 depthColor = float4(PSInput.color.rgb * 0.5, 1.0);
	float4 traspColor = float4(PSInput.color.rgb * 0.45, 0.8);
	float4 surfColor = float4(PSInput.color.rgb, 1.0);

	float4 nearColor = lerp(traspColor, depthColor, PSInput.color.a);
	PSInput.color = lerp(surfColor, nearColor, F);
#else
	PSInput.color.a = PSInput.position.z / FAR_CHUNKS_DISTANCE + 0.5;
#endif //FANCY
#endif

	PSInput.fragmentPosition = worldPos.xyz + VIEW_POS;
	PSInput.fragmentPosition.y += 0.0015;

	float3 cam_fix = worldPos.xyz + VIEW_POS;
	float3 fragment_pos = cam_fix;
	fragment_pos.y += 0.0015;
	PSInput.lookVector = fragment_pos - VIEW_POS;

}
