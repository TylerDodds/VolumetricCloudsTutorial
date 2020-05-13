#if !defined(VCT_FRAGMENT_RAYMARCHING_INCLUDED)
#define VCT_FRAGMENT_RAYMARCHING_INCLUDED

#include "UnityCG.cginc"
#include "CloudConstants.cginc"
#include "RaymarchInterval.cginc"
#include "RaymarchIntegral.cginc"

/// From pixel shader fragment information, reconstruct scene depth and view ray position for raymarching. 
/// Get raymarch interval based on earth's size, and perform raymarching.
/// Returns transmittance, sun intensity fraction, ambient intensity fraction
float4 FragmentTransmittanceAndIntegratedIntensitiesAndDepth(float linear01Depth, float3 ray, float offset, out float3 worldSpaceDirection, out float depthWeighted)
{
	float3 startPos = _WorldSpaceCameraPos + ray;
	worldSpaceDirection = normalize(ray);

	#define SET_FAR_DEPTH depthWeighted = _farDepth;return float4(1, 0, 0, 0);
	//TODO improved handling of _fadeHorizonAngle//TODO use Linear01Depth as raymarch stopping criterion instead

	// Reconstruct world space position & direction towards this screen pixel.
	if (linear01Depth < 1)
	{
		SET_FAR_DEPTH
	}
	//TODO Handle cases of depth lookup when downsampling

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