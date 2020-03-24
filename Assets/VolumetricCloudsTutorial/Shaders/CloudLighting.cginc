#if !defined(VCT_CLOUD_LIGHTING_INCLUDED)
#define VCT_CLOUD_LIGHTING_INCLUDED

#include "LightUtil.cginc"


uniform float _EccentricityForwards;
uniform float _EccentricityBackwards;
uniform float4 _MultiScatteringFactors_Extinction_Eccentricity_Intensity;

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

	float result = 0.0f;
	[unroll]
	for (int octaveIndex = 0; octaveIndex < 2; octaveIndex++)
	{	
		float transmittance = pow(baseTransmittance, pow(_MultiScatteringFactors_Extinction_Eccentricity_Intensity.x, octaveIndex));
		float eccentricityMultiplier = pow(_MultiScatteringFactors_Extinction_Eccentricity_Intensity.y, octaveIndex);
		float phase = CloudPhase(cosTheta, eccentricityMultiplier);
		result += phase * transmittance * pow(_MultiScatteringFactors_Extinction_Eccentricity_Intensity.z, octaveIndex);
	}

	//TODO Height scattering probability
	//TODO Depth scattering probability

	return result;
}

#endif // VCT_CLOUD_LIGHTING_INCLUDED