#if !defined(VCT_DEPTH_SAMPLING_INCLUDED)
#define VCT_DEPTH_SAMPLING_INCLUDED

#include "UnityCG.cginc"

float SampleLinear01Depth(sampler2D _CameraDepthTexture, float2 uv_depth)//TODO Use this depth sample,
{
	float zsample = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_depth);
	float depth = Linear01Depth(zsample);
	return depth;
}

float GetFarLinear01Depth_Downsample1(sampler2D depthTex, float2 uv, float2 texelSize)//TODO Remove this if not needed
{
	float4 o = texelSize.xyxy * float2(-1, 1).xxyy * 1;//Shift of -/+ quarter texel to sample center of neighbouring non-downscaled depth texture
	float depth1 = SampleLinear01Depth(depthTex, uv + o.xy);
	float depth2 = SampleLinear01Depth(depthTex, uv + o.zy);
	float depth3 = SampleLinear01Depth(depthTex, uv + o.xw);
	float depth4 = SampleLinear01Depth(depthTex, uv + o.zw);
	return max(max(max(depth1, depth2), depth3), depth4);
}

float GetFarLinear01Depth(sampler2D depthTex, float2 uv, float2 texelSize)
{
	#if defined(DOWNSAMPLE_1)
	#elif defined(DOWNSAMPLE_2)
	#else
	#endif
	return SampleLinear01Depth(depthTex, uv);
}

#endif // VCT_DEPTH_SAMPLING_INCLUDED