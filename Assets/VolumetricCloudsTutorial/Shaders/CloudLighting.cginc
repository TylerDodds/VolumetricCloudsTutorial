#if !defined(VCT_CLOUD_LIGHTING_INCLUDED)
#define VCT_CLOUD_LIGHTING_INCLUDED

#include "LightUtil.cginc"


uniform float _EccentricityForwards;
uniform float _EccentricityBackwards;

float CloudPhase(float cosTheta, float eccentricityMultiplier)
{
	float phaseForward = PhaseFunction(cosTheta, _EccentricityForwards * eccentricityMultiplier);
	float phaseBackwards = PhaseFunction(cosTheta, _EccentricityBackwards * eccentricityMultiplier);
	float phase = max(phaseForward, phaseBackwards);
	phase = max(0, phase);
	return phase;
}

/// At a given point in the cloud and view direction from the camera, determine the 
/// intensity of scattered light from the sun through this point to the camera.
float GetSunLightScatteringIntensity(float3 worldPos, float3 viewDir, float baseDensity, float stepSize)
{
	const float cosTheta = dot(viewDir, GetWorldSpaceLightDirection());

	const float baseTransmittance = 1;
	//TODO Get light-to-cloud optical distance and transmittance (self-shadowing)
	//TODO transmittance lightening

	float transmittance = baseTransmittance;
	float eccentricityMultiplier = 1;//TODO multi-scattering approximation
	float phase = CloudPhase(cosTheta, eccentricityMultiplier);
	float result = phase * transmittance;
	//TODO phase function

	//TODO Height scattering probability
	//TODO Depth scattering probability

	return result;
}

#endif // VCT_CLOUD_LIGHTING_INCLUDED