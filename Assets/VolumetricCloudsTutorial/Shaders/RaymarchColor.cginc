#if !defined(VCT_RAYMARCH_COLOR_INCLUDED)
#define VCT_RAYMARCH_COLOR_INCLUDED

#include "UnityLightingCommon.cginc"

/// From raymarch results of transmittance, integrated sun light intensity, integrated ambient light intensity, and average depth, 
/// along with ambient light color,
/// determine the final pixel color value.
fixed4 RaymarchColorLitAnalyticalTransmittanceIntensity(float4 transmittanceAndIntensitiesAndDepth, fixed3 ambient)
{
	//Multiply sun color my intensity and ambient colour by density
	float4 result = float4(0, 0, 0, saturate(1 - transmittanceAndIntensitiesAndDepth.r));

	fixed3 sunColor = _LightColor0;
	result.rgb += transmittanceAndIntensitiesAndDepth.g * sunColor;

	result.rgb += transmittanceAndIntensitiesAndDepth.b * ambient;

#if UNITY_COLORSPACE_GAMMA
	result.rgb = LinearToGammaSpace(result.rgb);
	result.a = LinearToGammaSpaceExact(result.a);
#endif
	return result;
}

#endif // VCT_RAYMARCH_COLOR_INCLUDED