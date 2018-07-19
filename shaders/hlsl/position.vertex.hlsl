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

struct VS_Input
{
	float3 position : POSITION;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input
{
	float4 position : SV_Position;
#ifdef GEOMETRY_INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	uint renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

ROOT_SIGNATURE
void main(in VS_Input VSInput, out PS_Input PSInput)
{
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul( WORLDVIEWPROJ_STEREO[i], float4( VSInput.position, 1 ) );
#else
	PSInput.position = mul(WORLDVIEWPROJ, float4(VSInput.position, 1));
#endif
#ifdef GEOMETRY_INSTANCEDSTEREO
	PSInput.instanceID = VSInput.instanceID;
#endif 
#ifdef VERTEXSHADER_INSTANCEDSTEREO
	PSInput.renTarget_id = VSInput.instanceID;
#endif
}