#if !defined(VCT_RAYMARCH_INTEGRAL_INCLUDED)
#define VCT_RAYMARCH_INTEGRAL_INCLUDED

#include "RaymarchInterval.cginc"
#include "CloudDensity.cginc"
#include "CloudLighting.cginc"

static const float _opaqueCutoff = 0.005;
static const float _wetIntensityFraction = 0.3;//TODO parametrize
uniform float _SigmaExtinction = 0.1;
uniform float _SigmaScattering = 0.1;

/// Returns transmittance, sun intensity fraction, ambient intensity fraction, and depth for a given
/// raymarch starting positiong and direction, raymarch distance, view vector start position, and offset along the ray.
float4 RaymarchTransmittanceAndIntegratedIntensityAndDepth(float3 raymarchStart, float3 worldDirection, float distance, float3 startPos, float offset)
{
	int numSteps = GetNumberOfSteps(distance);
	float stepSizeBase = distance / numSteps;

	float currentOffset = offset * stepSizeBase;
	float3 worldMarchPos = raymarchStart + currentOffset * worldDirection;

	float4 transmittanceIntensitiesDepthAccumulator = float4(1, 0, 0, 0);
	float depthWeightSum = 0;
	float mipLod = 0;

	float baseDensityCurrent = 0;

	float offsetMax = numSteps * stepSizeBase;
	float wetness;
	float3 animatedPos;
	float heightFraction, erosion;
	baseDensityCurrent = GetBaseDensity(worldMarchPos, mipLod, wetness, animatedPos, heightFraction, erosion);

	UNITY_LOOP
		for (int step = 0; step < numSteps && currentOffset < offsetMax && transmittanceIntensitiesDepthAccumulator.r > _opaqueCutoff; step++)
		{
			const float density = GetDetailDensity(worldMarchPos, animatedPos, heightFraction, mipLod, baseDensityCurrent, erosion);

			if (density > 0)
			{
				const float extinction = density * _SigmaExtinction;
				const float scattering = density * _SigmaScattering;
				const float clampedExtinction = max(extinction, 0.0000001);
				const float transmittance = exp(-extinction * stepSizeBase);

				float scatteredIntensity = scattering * GetSunLightScatteringIntensity(worldMarchPos, worldDirection, baseDensityCurrent, stepSizeBase) * lerp(1.0, _wetIntensityFraction, wetness);

				float integratedIntensity = (scatteredIntensity - scatteredIntensity * transmittance) / clampedExtinction;
				float integratedIntensityAmbient = (scattering - scattering * transmittance) / clampedExtinction;//Multi-scattering approximation only on the sun-light term, not ambient term
				//TODO Determine correct extinction-to-camera value. Wrennige's brief paper seems to indicate it's only the shadow extinction term, not the to-camera term, so we're just 'lightening' the light reaching the sample point, not affecting our blending operator.

				float extinctionToCamera = transmittanceIntensitiesDepthAccumulator.r;
				// TODO Adjustments from 'Beer-Powder' approximation

				transmittanceIntensitiesDepthAccumulator.g += integratedIntensity * extinctionToCamera;
				transmittanceIntensitiesDepthAccumulator.b += integratedIntensityAmbient * extinctionToCamera;
				transmittanceIntensitiesDepthAccumulator.r *= transmittance;

				float depthWeight = (1 - transmittance);
				transmittanceIntensitiesDepthAccumulator.w += depthWeight * length(worldMarchPos - startPos);
				depthWeightSum += depthWeight;
			}

			//TODO adaptive step size based on recent density history
			currentOffset += stepSizeBase;
			worldMarchPos = raymarchStart + currentOffset * worldDirection;
		}

	transmittanceIntensitiesDepthAccumulator.w /= max(depthWeightSum, 1e-6);
	if (transmittanceIntensitiesDepthAccumulator.w == 0.0f)
	{
		transmittanceIntensitiesDepthAccumulator.w = length(worldMarchPos - startPos);
	}

	return transmittanceIntensitiesDepthAccumulator;
}

#endif // VCT_RAYMARCH_INTEGRAL_INCLUDED