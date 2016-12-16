#if defined(__INTELLISENSE__)
	#include ".\..\..\BlockShader\Includes\ShaderConstants.fxh"
	#define TEXEL_AA
	#define TEXEL_AA_FEATURE
	#define VERSION  0xa000
	#define NEAR_WATER
#else
	#include "ShaderConstants.fxh"
#endif

struct VS_Input
{
    float3 position : POSITION;
    float2 uv : TEXCOORD_0;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


struct PS_Input
{
    float4 position : SV_Position;
    float3 worldPostion : POSITION;
    float2 uv : TEXCOORD_0;
#ifdef INSTANCEDSTEREO
	uint instanceID : SV_InstanceID;
#endif
};


void main(in VS_Input VSInput, out PS_Input PSInput)
{
    PSInput.uv = VSInput.uv;
#ifdef INSTANCEDSTEREO
	int i = VSInput.instanceID;
	PSInput.position = mul( WORLDVIEWPROJ_STEREO[i], float4( VSInput.position, 1 ) );
	PSInput.instanceID = i;
#else
    PSInput.position = mul(WORLDVIEWPROJ, float4(VSInput.position, 1));
    PSInput.worldPostion = mul(WORLD, float4(VSInput.position, 1)).xyz;
#endif
}