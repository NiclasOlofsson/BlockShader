#if defined(__INTELLISENSE__)
	#include ".\..\..\BlockShader\Includes\ShaderConstants.fxh"
	#include ".\..\..\BlockShader\Includes\Util.fxh"
	#define TEXEL_AA
	#define TEXEL_AA_FEATURE
	#define VERSION  0xa000
	#define NEAR_WATER
#else
	#include "ShaderConstants.fxh"
	#include "Util.fxh"
#endif

struct PS_Input
{
	float4 position : SV_Position;
	float4 color : COLOR;
};

struct PS_Output
{
	float4 color : SV_Target;
};

void main(in PS_Input PSInput, out PS_Output PSOutput)
{
	PSOutput.color = PSInput.color;
}