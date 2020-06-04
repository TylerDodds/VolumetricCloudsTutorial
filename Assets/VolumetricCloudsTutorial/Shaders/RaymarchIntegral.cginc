#if !defined(VCT_RAYMARCH_INTEGRAL_INCLUDED)
#define VCT_RAYMARCH_INTEGRAL_INCLUDED

#include "RaymarchInterval.cginc"
#include "CloudDensity.cginc"
#include "CloudLighting.cginc"

static const float _opaqueCutoff = 0.005;
uniform float _WetIntensityFraction = 0.3;
uniform float _SigmaScattering = 0.1;

/// Updates the final offset and gets the next density from GetBaseDensity.
/// If ADAPTIVE_STEPS is used, it uses a multiple of the base step size depending on how many of the previous base densities are below zero, indicating the raymarch is in a region of empty density.
/// When a positive base density is hit, it cancels the step and then begins using a single base step.
/// Otherwise, it uses just a single step of the base step size.
float3 GetNextOffsetAndBaseDensity(float3 baseDensities, float3 offsets, float stepSizeBase, float3 raymarchStart, float3 raymarchDirection, float2 lods, out float wetness, out float3 animatedPos, out float heightFraction, out float erosion)
{
	float nextOffset = offsets.z + stepSizeBase;
	float finalOffset = nextOffset;
	float3 finalPosition;
	float2 baseDensity;
	#define UPDATE_POS_DEN finalPosition = raymarchStart + raymarchDirection * finalOffset; baseDensity = GetBaseDensityAtLODs(finalPosition, lods, wetness, animatedPos, heightFraction, erosion);
	#if defined(ADAPTIVE_STEPS)
	if (all(step(baseDensities, 0)))
	{
		int stepFactor = baseDensities.z <= baseDensities.y ? (baseDensities.y < baseDensities.x ? ADAPTIVE_FRACTION_DENSITY_DECREASING_MONOTONIC : ADAPTIVE_FRACTION_DENSITY_DECREASING_LOCAL_MAXIMUM) : ADAPTIVE_FRACTION_DENSITY_INCREASING;
		finalOffset = offsets.z + stepFactor * stepSizeBase;
		UPDATE_POS_DEN
		if (baseDensity.x > 0)
		{
			finalOffset = nextOffset;
			UPDATE_POS_DEN
		}
	}
	else
	{
		UPDATE_POS_DEN
	}
	#else
	UPDATE_POS_DEN
	#endif
	return float3(finalOffset, baseDensity.x, baseDensity.y);
}


/// Returns transmittance, sun intensity fraction, ambient intensity fraction, and depth for a given
/// raymarch starting positiong and direction, raymarch distance, view vector start position, and offset along the ray.
float4 RaymarchTransmittanceAndIntegratedIntensitiesAndDepth(float3 raymarchStart, float3 worldDirection, float distance, float3 startPos, float offset, out float depthApprox)
{
	int numSteps = GetNumberOfSteps(distance, worldDirection);
	float stepSizeBase = distance / numSteps;

	float currentOffset = offset * stepSizeBase;
	float3 worldMarchPos = raymarchStart + currentOffset * worldDirection;

	float4 transmittanceIntensitiesDepthAccumulator = float4(1, 0, 0, 0);
	depthApprox = 0;
	float depthWeightSum = 0;
	float2 mipLod = float2(0, 2);

	float baseDensityStep1 = 0;
	float baseDensityStep2 = 0;
	float offsetStep1 = currentOffset - stepSizeBase;
	float offsetStep2 = currentOffset - 2 * stepSizeBase;
	float2 baseDensityCurrent = 0;

	float offsetMax = numSteps * stepSizeBase;
	float wetness;
	float3 animatedPos;
	float heightFraction, erosion;

	baseDensityCurrent = GetBaseDensityAtLODs(worldMarchPos, mipLod, wetness, animatedPos, heightFraction, erosion);
	UNITY_LOOP
		for (int step = 0; step < numSteps && currentOffset < offsetMax && transmittanceIntensitiesDepthAccumulator.r > _opaqueCutoff; step++)
		{
			const float detailDensity = GetDetailDensity(worldMarchPos, animatedPos, heightFraction, mipLod, baseDensityCurrent.x, erosion);
			const float density = GetFinalDensity(detailDensity);

			if (density > 0)
			{
				const float extinction = density * _SigmaExtinction;
				const float scattering = density * _SigmaScattering;
				const float clampedExtinction = max(extinction, 0.0000001);
				const float transmittance = exp(-extinction * stepSizeBase);

				float isotropicScatteringRate;
				float scatteredIntensity = scattering * GetSunLightScatteringIntensity(worldMarchPos, worldDirection, heightFraction, GetFinalDensity(baseDensityCurrent.y), stepSizeBase, isotropicScatteringRate) * lerp(1.0, _WetIntensityFraction, wetness);
				float2 scatteredAmbientIntensities = scattering * GetAmbientIntensityTopBottom(heightFraction, _SigmaExtinction) * isotropicScatteringRate;

				float integratedIntensity = (scatteredIntensity - scatteredIntensity * transmittance) / clampedExtinction;
				float2 integratedAmbientIntensities = (scatteredAmbientIntensities - scatteredAmbientIntensities * transmittance) / clampedExtinction;//Multi-scattering approximation only on the sun-light term, not ambient term

				float extinctionToCamera = transmittanceIntensitiesDepthAccumulator.r;

				transmittanceIntensitiesDepthAccumulator.g += integratedIntensity * extinctionToCamera;
				transmittanceIntensitiesDepthAccumulator.ba += integratedAmbientIntensities * extinctionToCamera;
				transmittanceIntensitiesDepthAccumulator.r *= transmittance;

				float depthWeight = (1 - transmittance);
				depthApprox += depthWeight * length(worldMarchPos - startPos);
				depthWeightSum += depthWeight;
			}

			float3 densities = float3(baseDensityStep2, baseDensityStep1, baseDensityCurrent.x);
			float3 offsets = float3(offsetStep2, offsetStep1, currentOffset);
			float3 nextOffsetAndDensity = GetNextOffsetAndBaseDensity(densities, offsets, stepSizeBase, raymarchStart, worldDirection, mipLod, wetness, animatedPos, heightFraction, erosion);
			baseDensityStep2 = baseDensityStep1;
			baseDensityStep1 = baseDensityCurrent.x;
			baseDensityCurrent = nextOffsetAndDensity.yz;
			offsetStep2 = offsetStep1;
			offsetStep1 = currentOffset;
			currentOffset = nextOffsetAndDensity.x;
			worldMarchPos = raymarchStart + currentOffset * worldDirection;
		}

	depthApprox /= max(depthWeightSum, 1e-6);
	if (depthApprox == 0.0f)
	{
		depthApprox = length(worldMarchPos - startPos);
	}

	return transmittanceIntensitiesDepthAccumulator;
}

#endif // VCT_RAYMARCH_INTEGRAL_INCLUDED
