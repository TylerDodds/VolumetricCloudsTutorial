#if !defined(VCT_CLOUD_LIGHTING_INCLUDED)
#define VCT_CLOUD_LIGHTING_INCLUDED

/// At a given point in the cloud and view direction from the camera, determine the 
/// intensity of scattered light from the sun through this point to the camera.
float GetSunLightScatteringIntensity(float3 worldPos, float3 viewDir, float baseDensity, float stepSize)
{
	return 1;//TODO lighting calculations
}

#endif // VCT_CLOUD_LIGHTING_INCLUDED