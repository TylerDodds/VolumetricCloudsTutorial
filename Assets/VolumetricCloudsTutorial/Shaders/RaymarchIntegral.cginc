#if !defined(VCT_RAYMARCH_INTEGRAL_INCLUDED)
#define VCT_RAYMARCH_INTEGRAL_INCLUDED

/// Returns transmittance, sun intensity fraction, ambient intensity fraction, and depth
float4 RaymarchTransmittanceAndIntegratedIntensityAndDepth(float3 raymarchStart, float3 worldDirection, float distance, float3 startPos, float offset)
{
	int numSteps = GetNumberOfSteps(distance, worldDirection);
	float stepSizeBase = distance / numSteps;

	float currentOffset = offset * stepSizeBase;
	float3 worldMarchPos = raymarchStart + currentOffset * worldDirection;

	float4 transmittanceIntensitiesDepthAccumulator = float4(1, 0, 0, 0);

	//TODO 

	return transmittanceIntensitiesDepthAccumulator;
}

#endif // VCT_RAYMARCH_INTEGRAL_INCLUDED