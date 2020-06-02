#if !defined(VCT_CLOUD_LIGHTING_INCLUDED)
#define VCT_CLOUD_LIGHTING_INCLUDED

#include "LightUtil.cginc"
#include "CloudDensity.cginc"

uniform float _SigmaExtinction;
uniform float _EccentricityForwards;
uniform float _EccentricityBackwards;
uniform float4 _MultiScatteringFactors_Extinction_Eccentricity_Intensity;
uniform float _ShadowStepBase;
uniform float4 _HeightScattering_Low_High_Min_Power;
uniform float4 _DepthScattering_Low_High_Min_Max;

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

	float densityIntegral = 0;
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
		densityIntegral += density * stepSize;

		mipmapOffset += 0.5;
		worldPos += delta;
	}

	return densityIntegral * _SigmaExtinction;
}

float LightenTransmittance(float transmittance, float cosTheta)
{
	float lightenedTransmittance = pow(transmittance, 0.25) * 0.7;
	//Do less lightening in directions where forward scattering will be very strong (theta close to zero)
	float lightenedFrac = saturate(Remap(cosTheta, 0.7, 1.0, 1.0, 0.25));
	return max(transmittance, lightenedTransmittance * lightenedFrac);
}

float GetIsotropicScatteringRate(float heightFraction, float baseDensity, float stepSize, float lightDirectionOpticalDistance)
{
	float verticalScatteringRate = pow(RemapClamped(heightFraction, _HeightScattering_Low_High_Min_Power.x, _HeightScattering_Low_High_Min_Power.y, _HeightScattering_Low_High_Min_Power.z, 1.0), _HeightScattering_Low_High_Min_Power.w);
	float depthScatteringBase = pow(saturate(baseDensity) + 1e-6, RemapClamped(heightFraction, _DepthScattering_Low_High_Min_Max.x, _DepthScattering_Low_High_Min_Max.y, _DepthScattering_Low_High_Min_Max.z, _DepthScattering_Low_High_Min_Max.w));
	float depthScatteringRate = lerp(0.05 + depthScatteringBase, 1.0, saturate(lightDirectionOpticalDistance / depthScatteringDistanceScale));
	float isotropicScatteringRate = verticalScatteringRate * depthScatteringRate;
	return isotropicScatteringRate;
}

/// At a given point in the cloud and view direction from the camera, determine the 
/// intensity of scattered light from the sun through this point to the camera.
float GetSunLightScatteringIntensity(float3 worldPos, float3 viewDir, float heightFraction, float baseDensity, float stepSize, out float isotropicScatteringRate)
{
	const float cosTheta = dot(viewDir, GetWorldSpaceLightDirection());

	const float lightDirectionOpticalDistance = GetLightCloudOpticalDistance(worldPos);
	const float lightTransmittance = exp(-lightDirectionOpticalDistance);
	const float baseTransmittance = LightenTransmittance(lightTransmittance, cosTheta);

	float result = 0.0f;
	[unroll]
	for (int octaveIndex = 0; octaveIndex < 2; octaveIndex++)
	{	
		float transmittance = pow(baseTransmittance, pow(_MultiScatteringFactors_Extinction_Eccentricity_Intensity.x, octaveIndex));
		float eccentricityMultiplier = pow(_MultiScatteringFactors_Extinction_Eccentricity_Intensity.y, octaveIndex);
		float phase = CloudPhase(cosTheta, eccentricityMultiplier);
		result += phase * transmittance * pow(_MultiScatteringFactors_Extinction_Eccentricity_Intensity.z, octaveIndex);
	}

	isotropicScatteringRate = GetIsotropicScatteringRate(heightFraction, baseDensity, stepSize, lightDirectionOpticalDistance);
	result *= isotropicScatteringRate;

	return result;
}

#endif // VCT_CLOUD_LIGHTING_INCLUDED