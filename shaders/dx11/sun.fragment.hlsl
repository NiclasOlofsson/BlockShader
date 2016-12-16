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
    float3 worldPostion : POSITION;
    float2 uv : TEXCOORD_0_FB_MSAA;
};

struct PS_Output
{
    float4 color : SV_Target;
};

void main(in PS_Input PSInput, out PS_Output PSOutput)
{
#if !defined(TEXEL_AA) || !defined(TEXEL_AA_FEATURE) || (VERSION < 0xa000 /*D3D_FEATURE_LEVEL_10_0*/) 
	float4 diffuse = TEXTURE_0.Sample(TextureSampler0, PSInput.uv);
#else
    float4 diffuse = texture2D_AA(TEXTURE_0, TextureSampler0, PSInput.uv);
#endif

#ifdef ALPHA_TEST
    if( diffuse.a < 0.5 )
    {
        discard;
    }
#endif

    PSOutput.color = CURRENT_COLOR * diffuse;
}
