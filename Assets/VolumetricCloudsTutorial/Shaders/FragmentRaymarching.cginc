#if !defined(VCT_FRAGMENT_RAYMARCHING_INCLUDED)
#define VCT_FRAGMENT_RAYMARCHING_INCLUDED

#include "UnityCG.cginc"
#include "CloudConstants.cginc"
#include "RaymarchInterval.cginc"
#include "RaymarchIntegral.cginc"

/// From pixel shader fragment information, reconstruct scene depth and view ray position for raymarching. 
/// Get raymarch interval based on earth's size, and perform raymarching.
/// Returns transmittance, sun intensity fraction, ambient intensity fraction
float4 FragmentTransmittanceAndIntegratedIntensitiesAndDepth(float2 uv_depth, float3 ray, float offset, sampler2D _CameraDepthTexture, out float3 worldSpaceDirection, out float depthWeighted)
{
	float3 startPos = _WorldSpaceCameraPos + ray;
	worldSpaceDirection = normalize(ray);

	#define SET_FAR_DEPTH depthWeighted = _farDepth;return float4(1, 0, 0, 0);
	//TODO improved handling of _fadeHorizonAngle//TODO use Linear01Depth as raymarch stopping criterion instead

	// Reconstruct world space position & direction towards this screen pixel.
	float zsample = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv_depth);
	#if UNITY_REVERSED_Z
	if (zsample > 0)
	#else
	if (zsample < 1)
	#endif
	{
		SET_FAR_DEPTH
	}
	
	float depth = Linear01Depth(zsample * (zsample < 1.0));

	float3 raymarchStart;
	float raymarchDistance, cloudHeightDistance;

	if (worldSpaceDirection.y < -fadeHorizonAngle)
	{
		SET_FAR_DEPTH
	}

	if (!GetCloudRaymarchInterval_EarthCurvature(_WorldSpaceCameraPos, worldSpaceDirection, raymarchStart, raymarchDistance, cloudHeightDistance))
	{
		SET_FAR_DEPTH
	}

	float4 transmittanceAndIntensities = RaymarchTransmittanceAndIntegratedIntensitiesAndDepth(raymarchStart, worldSpaceDirection, raymarchDistance, startPos, offset, depthWeighted);
	return transmittanceAndIntensities;
}

#endif // VCT_FRAGMENT_RAYMARCHING_INCLUDED