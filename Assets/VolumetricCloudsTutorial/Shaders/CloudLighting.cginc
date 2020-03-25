﻿#if !defined(VCT_CLOUD_LIGHTING_INCLUDED)
#define VCT_CLOUD_LIGHTING_INCLUDED

#include "LightUtil.cginc"
#include "CloudDensity.cginc"

uniform float _SigmaExtinction;
uniform float _EccentricityForwards;
uniform float _EccentricityBackwards;
uniform float4 _MultiScatteringFactors_Extinction_Eccentricity_Intensity;
uniform float _ShadowStepBase;

float CloudPhase(float cosTheta, float eccentricityMultiplier)
{
	float phaseForward = PhaseFunction(cosTheta, _EccentricityForwards * eccentricityMultiplier);
	float phaseBackwards = PhaseFunction(cosTheta, _EccentricityBackwards * eccentricityMultiplier);
	float phase = max(phaseForward, phaseBackwards);
	phase = max(0, phase);
	return phase;
}

static const float _extinctionStepSizeMultipliers[5] =
{ 1, 1, 2, 4, 8 };

float GetLightCloudOpticalDistance(float3 worldPos)
{
	float3 lightDirWorld = GetWorldSpaceLightDirection();

	float opticalDistance = 0;
	float mipmapOffset = 0.5;

	[unroll]
	for (int step = 0; step < 5; step++)
	{
		float stepSize = _extinctionStepSizeMultipliers[step] * _ShadowStepBase;
		float3 delta = stepSize * lightDirWorld * 0.5;
		worldPos += delta;
		//We take the sample in the middle of the range, at increasing mipmap value, to estimate a sort of average density value per step range

		float wetness, heightFraction, erosion;
		float3 animatedPos;
		const float baseDensity = GetBaseDensity(worldPos, mipmapOffset, wetness, animatedPos, heightFraction, erosion);
		const float density = GetFinalDensity(max(0,baseDensity));//Since base density can be negative, ensure we clamp at 0 in physical calculation
		opticalDistance += density * stepSize;

		mipmapOffset += 0.5;
		worldPos += delta;
	}

	return opticalDistance;
}

/// At a given point in the cloud and view direction from the camera, determine the 
/// intensity of scattered light from the sun through this point to the camera.
float GetSunLightScatteringIntensity(float3 worldPos, float3 viewDir, float baseDensity, float stepSize)
{
	const float cosTheta = dot(viewDir, GetWorldSpaceLightDirection());

	const float lightDirectionOpticalDistance = GetLightCloudOpticalDistance(worldPos);
	const float lightTransmittance = exp(-_SigmaExtinction * lightDirectionOpticalDistance);
	//TODO transmittance lightening
	const float baseTransmittance = lightTransmittance;


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