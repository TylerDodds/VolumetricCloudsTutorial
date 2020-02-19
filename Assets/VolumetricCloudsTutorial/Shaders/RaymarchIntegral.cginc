#if !defined(VCT_RAYMARCH_INTEGRAL_INCLUDED)
#define VCT_RAYMARCH_INTEGRAL_INCLUDED

/// Returns transmittance, sun intensity fraction, ambient intensity fraction, and depth for a given
/// raymarch starting positiong and direction, raymarch distance, view vector start position, and offset along the ray.
float4 RaymarchTransmittanceAndIntegratedIntensityAndDepth(float3 raymarchStart, float3 worldDirection, float distance, float3 startPos, float offset)
{
	int numSteps = GetNumberOfSteps(distance);
	float stepSizeBase = distance / numSteps;

	float currentOffset = offset * stepSizeBase;
	float3 worldMarchPos = raymarchStart + currentOffset * worldDirection;

	float4 transmittanceIntensitiesDepthAccumulator = float4(1, 0, 0, 0);

	//TODO perform raymarching

	return transmittanceIntensitiesDepthAccumulator;
}

#endif // VCT_RAYMARCH_INTEGRAL_INCLUDED