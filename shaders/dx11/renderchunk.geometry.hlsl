#if defined(__INTELLISENSE__)
	#include ".\..\..\BlockShader\Includes\ShaderConstants.fxh"
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
#endif

struct GeometryShaderInput
{
    float4 pos : SV_POSITION;
    float3 fragmentPosition : POSI;
    float3 lookVector : POSITION;
    float water_plane_flag : WATER_FLAG;
#ifndef BYPASS_PIXEL_SHADER
    lpfloat4 color : COLOR;
    snorm float2 uv0 : TEXCOORD_0;
    snorm float2 uv1 : TEXCOORD_1;
#endif
#ifdef NEAR_WATER
    float cameraDist : TEXCOORD_2;
    float3 normal : NORMAL;
#endif
#ifdef FOG
    float4 fogColor : FOG_COLOR;
#endif
#ifdef INSTANCEDSTEREO
	uint				instanceID		: SV_InstanceID;
#endif
};


// Per-pixel color data passed through the pixel shader.
struct GeometryShaderOutput
{
    float4 pos : SV_POSITION;
    float3 fragmentPosition : POSI;
    float3 lookVector : POSITION;
    float water_plane_flag : WATER_FLAG;
#ifndef BYPASS_PIXEL_SHADER
    lpfloat4 color : COLOR;
    snorm float2 uv0 : TEXCOORD_0;
    snorm float2 uv1 : TEXCOORD_1;
#endif
#ifdef NEAR_WATER
    float cameraDist : TEXCOORD_2;
    float3 normal : NORMAL;
#endif
#ifdef FOG
    float4 fogColor : FOG_COLOR;
#endif
#ifdef INSTANCEDSTEREO
	uint				renTarget_id : SV_RenderTargetArrayIndex;
#endif
};

bool inBounds(float3 worldPos)
{
    bool inBounds = true;
    if (worldPos.x < CHUNK_CLIP_MIN.x ||
		worldPos.x > CHUNK_CLIP_MAX.x ||
		worldPos.z < CHUNK_CLIP_MIN.y ||
		worldPos.z > CHUNK_CLIP_MAX.y)
    {
        inBounds = false;
    }

    return inBounds;
}


static const float3 UNIT_Y = float3(0, 1, 0);

float GetWaterDisplacementInternal(float3 worldPos, float2 direction, float A, float S, float L)
{
    float3 relPos = (worldPos - VIEW_POS) * -1;
    float cameraDepth = length(relPos);
    float F = 1 - (cameraDepth / FAR_CHUNKS_DISTANCE);

    float3 pos = worldPos;
    float x = pos.x;
    float y = pos.y;
    float z = pos.z;

    float w = 6.28 / L;
    float t = TIME;
    float ph = S * 6.28 / L;

    return lerp(0, A * sin(dot(direction, float2(x, z)) * w + t * ph) + A, F);

    //if (FOG_CONTROL.x < 55)
    //{
    //    direction = float2(0, 1);
    //    A = 0.05;
    //    S = 4;
    //    L = 2;

    //    w = 6.28 / L;
    //    t = TIME;
    //    ph = S * 6.28 / L;

    //    PSInput.position.y -= lerp(0, A * sin(dot(direction, float2(x, z)) * w + t * ph) + A, F);
    //}
}

float GetWaterDisplacement(float3 worldPos)
{
    float2 direction = float2(0.5, 1);
    float factor = abs(clamp(FOG_CONTROL.x + 0.50, 0, 1));
    float A = 0.05 + lerp(0.3, 0, factor);
    float S = 2;
    float L = 4;

    return GetWaterDisplacementInternal(worldPos, direction, A, S, L);
}

float3 GetNormal(float3 v1, float3 v2, float3 v3)
{
    float3 a, b;
    a = v1 - v2;
    b = v1 - v3;
    return cross(a, b);
}

bool IsAtWaterLimit(float3 pos)
{
    return frac(pos.y) > 0.80 && frac(pos.y) < 0.98;
}

GeometryShaderOutput Tesselate(GeometryShaderInput input0, GeometryShaderInput input1, inout TriangleStream<GeometryShaderOutput> outS)
{
    GeometryShaderOutput output = (GeometryShaderOutput) 0;

    output.pos = lerp(input0.pos, input1.pos, 0.5);
    output.color = lerp(input0.color, input1.color, 0.5);
    output.uv0 = lerp(input0.uv0, input1.uv0, 0.5);
    output.uv1 = lerp(input0.uv1, input1.uv1, 0.5);
    output.fragmentPosition = lerp(input0.fragmentPosition, input1.fragmentPosition, 0.5);

    float3 pos0 = input0.fragmentPosition;
    float3 pos1 = input1.fragmentPosition;
    if (pos0.y >= pos1.y && frac(pos0.y) > 0.99)
    {
        // stream into water
    }
    else if (pos1.y > pos0.y && frac(pos1.y) > 0.99)
    {
        // stream into water
    }
    else if (pos1.y > pos0.y && !IsAtWaterLimit(pos1))
    {
        // stream from water
        // High point is water level, and lower point is not
    }
    else if (pos0.y > pos1.y && !IsAtWaterLimit(pos0))
    {
        // stream from water
    }
    else if (pos0.y == pos1.y && !IsAtWaterLimit(pos0))
    {
        // stream
    }
    else
    {
        float displacement = GetWaterDisplacement(output.fragmentPosition);
        output.pos.y -= displacement;
        output.fragmentPosition.y -= displacement;
    }
    //output.pos.y -= GetWaterDisplacementInternal(output.fragmentPosition, float2(1, 0.5), 0.05, 3, 1);

    output.lookVector = lerp(input0.lookVector, input1.lookVector, 0.5);
    output.water_plane_flag = input0.water_plane_flag;
#ifdef NEAR_WATER
    output.cameraDist = lerp(input0.cameraDist, input1.cameraDist, 0.5);
#endif
    //outS.Append(output);

    return output;
}

void WriteTriangle(GeometryShaderOutput pos1, GeometryShaderOutput pos2, GeometryShaderOutput pos3, inout TriangleStream<GeometryShaderOutput> outStream)
{
#ifdef NEAR_WATER
    float3 normal = GetNormal(pos1.fragmentPosition, pos2.fragmentPosition, pos3.fragmentPosition);
    pos1.normal = normal;
    pos2.normal = normal;
    pos3.normal = normal;
#endif
    outStream.Append(pos1);
    outStream.Append(pos2);
    outStream.Append(pos3);
    outStream.RestartStrip();
}

// passes through the triangles, except changint the viewport id to match the instance
[maxvertexcount(12)]
void main(triangle GeometryShaderInput input[3], inout TriangleStream<GeometryShaderOutput> outStream)
{
    GeometryShaderOutput output = (GeometryShaderOutput) 0;

#ifdef NEAR_WATER


    //bool doWave = frac(input[0].lookVector.y) > 0.887 && frac(input[0].lookVector.y) > 0.00789;
    bool doWave = frac(input[0].fragmentPosition.y) > 0.85 && frac(input[0].fragmentPosition.y) < 0.95;
    doWave = doWave || frac(input[1].fragmentPosition.y) > 0.85 && frac(input[1].fragmentPosition.y) < 0.95;
    doWave = doWave || frac(input[2].fragmentPosition.y) > 0.85 && frac(input[2].fragmentPosition.y) < 0.95;

    float3 normal = abs(normalize(GetNormal(input[0].fragmentPosition.xyz, input[1].fragmentPosition.xyz, input[2].fragmentPosition.xyz)));
    if (doWave || normal.x < 0.2 && normal.z < 0.2 && normal.y > 0.9)
    //if (doWave)
    {
        float lenA = abs(distance(input[0].pos.xz, input[1].pos.xz));
        float lenB = abs(distance(input[1].pos.xz, input[2].pos.xz));
        float lenC = abs(distance(input[2].pos.xz, input[0].pos.xz));

        GeometryShaderOutput pos1;
        GeometryShaderOutput pos2;
        GeometryShaderOutput pos3;

        if (lenB > lenA && lenB > lenC)
        {
    // T1
            pos1 = Tesselate(input[0], input[0], outStream);
            pos2 = Tesselate(input[0], input[1], outStream);
            pos3 = Tesselate(input[1], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T2
            pos1 = Tesselate(input[0], input[1], outStream);
            pos2 = Tesselate(input[1], input[1], outStream);
            pos3 = Tesselate(input[1], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T3
            pos1 = Tesselate(input[1], input[2], outStream);
            pos2 = Tesselate(input[2], input[2], outStream);
            pos3 = Tesselate(input[0], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T4
            pos1 = Tesselate(input[0], input[2], outStream);
            pos2 = Tesselate(input[0], input[0], outStream);
            pos3 = Tesselate(input[1], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);
        }
        else if (lenA > lenB && lenA > lenC)
        {
    // T1
            pos1 = Tesselate(input[0], input[0], outStream);
            pos2 = Tesselate(input[0], input[1], outStream);
            pos3 = Tesselate(input[0], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T2
            pos1 = Tesselate(input[0], input[1], outStream);
            pos2 = Tesselate(input[1], input[1], outStream);
            pos3 = Tesselate(input[1], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T3
            pos1 = Tesselate(input[1], input[2], outStream);
            pos2 = Tesselate(input[2], input[2], outStream);
            pos3 = Tesselate(input[1], input[0], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T4
            pos1 = Tesselate(input[2], input[2], outStream);
            pos2 = Tesselate(input[2], input[0], outStream);
            pos3 = Tesselate(input[0], input[1], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);
        }
        else if (lenC > lenB && lenC > lenB)
        {
    // T1
            pos1 = Tesselate(input[0], input[0], outStream);
            pos2 = Tesselate(input[0], input[1], outStream);
            pos3 = Tesselate(input[0], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T2
            pos1 = Tesselate(input[0], input[1], outStream);
            pos2 = Tesselate(input[1], input[1], outStream);
            pos3 = Tesselate(input[0], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T3
            pos1 = Tesselate(input[1], input[1], outStream);
            pos2 = Tesselate(input[1], input[2], outStream);
            pos3 = Tesselate(input[0], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);

    // T4
            pos1 = Tesselate(input[1], input[2], outStream);
            pos2 = Tesselate(input[2], input[2], outStream);
            pos3 = Tesselate(input[0], input[2], outStream);
            WriteTriangle(pos1, pos2, pos3, outStream);
        }
        else
        {
        }


        return;
    }

#endif

#ifdef INSTANCEDSTEREO
	int i = input[0].instanceID;
#endif
    {

        for (int j = 0; j < 3; j++)
        {
            output.pos = input[j].pos;
            output.color = input[j].color;
            output.uv0 = input[j].uv0;
            output.uv1 = input[j].uv1;
            output.fragmentPosition = input[j].fragmentPosition;
            output.lookVector = input[j].lookVector;
            output.water_plane_flag = input[j].water_plane_flag;
#ifndef BYPASS_PIXEL_SHADER
#endif
#ifdef NEAR_WATER
            output.cameraDist = input[j].cameraDist;
#endif

#ifdef INSTANCEDSTEREO
			output.renTarget_id = i;
#endif

#ifdef FOG
            output.fogColor = input[j].fogColor;
#endif
            outStream.Append(output);
        }
    }
}
