#if !defined(VCT_FRAGMENT_RAYMARCHING_INCLUDED)
#define VCT_FRAGMENT_RAYMARCHING_INCLUDED

#include "CloudConstants.cginc"
#include "RaymarchInterval.cginc"
#include "RaymarchIntegral.cginc"

/// From pixel shader fragment information, reconstruct scene depth and view ray position for raymarching. 
/// Get raymarch interval based on earth's size, and perform raymarching.
float4 FragmentTransmittanceAndintegratedIntensityAndDepth(float2 uv_depth, float3 ray, float offset, sampler2D _CameraDepthTexture, out float3 worldSpaceFragment, out float3 worldSpaceDirection)
{
	float3 startPos = _WorldSpaceCameraPos + ray;
	worldSpaceDirection = normalize(ray);
	// Reconstruct world space position & direction towards this screen pixel.
	float zsample = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_depth);
	if (zsample > 0)
	{
		worldSpaceFragment = _WorldSpaceCameraPos;
		return float4(1, 0, 0, _farDepth);
		//TODO use Linear01Depth as raymarch stopping criterion instead
	}

	float depth = Linear01Depth(zsample * (zsample < 1.0));

	float3 cameraToFragmentInWorldCoordinates = ray * depth;
	worldSpaceFragment = _WorldSpaceCameraPos + cameraToFragmentInWorldCoordinates;

	float3 raymarchStart;
	float raymarchDistance, cloudHeightDistance;

	if (worldSpaceDirection.y < -fadeHorizonAngle)
	{
		return float4(1, 0, 0, _farDepth);//TODO improved handling of _fadeHorizonAngle
	}

	if (!GetCloudRaymarchInterval_EarthCurvature(_WorldSpaceCameraPos, worldSpaceDirection, raymarchStart, raymarchDistance, cloudHeightDistance))
	{
		return float4(1, 0, 0, _farDepth);
	}

	float4 transmittanceAndIntensitiesAndDepth = RaymarchTransmittanceAndIntegratedIntensityAndDepth(raymarchStart, worldSpaceDirection, raymarchDistance, startPos, offset);
	return transmittanceAndIntensitiesAndDepth;
}

#endif // VCT_FRAGMENT_RAYMARCHING_INCLUDED