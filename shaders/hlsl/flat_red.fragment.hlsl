#if defined(__INTELLISENSE__)
	#include ".\..\..\BlockShader\Includes\ShaderConstants.fxh"
	#include ".\..\..\BlockShader\Includes\util.fxh"
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

struct PS_Input
{
    float4 position : SV_Position;
};

struct PS_Output
{
    float4 color : SV_Target;
};

ROOT_SIGNATURE
void main(in PS_Input PSInput, out PS_Output PSOutput)
{
    PSOutput.color = float4(1,0,0,1);
}