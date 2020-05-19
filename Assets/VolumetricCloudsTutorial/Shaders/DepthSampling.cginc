#if !defined(VCT_DEPTH_SAMPLING_INCLUDED)
#define VCT_DEPTH_SAMPLING_INCLUDED

#include "UnityCG.cginc"

float SampleLinear01Depth(sampler2D _CameraDepthTexture, float2 uv_depth)
{
	float zsample = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_depth);
	float depth = Linear01Depth(zsample);
	return depth;
}

#endif // VCT_DEPTH_SAMPLING_INCLUDED