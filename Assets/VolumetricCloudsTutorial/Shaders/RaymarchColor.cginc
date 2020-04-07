#if !defined(VCT_RAYMARCH_COLOR_INCLUDED)
#define VCT_RAYMARCH_COLOR_INCLUDED

#include "UnityLightingCommon.cginc"

/// From raymarch results of transmittance, integrated sun light intensity, integrated ambient light intensity, and average depth, 
/// along with ambient light color,
/// determine the final pixel color value.
fixed4 RaymarchColorLitAnalyticalTransmittanceIntensity(float4 transmittanceAndIntegratedIntensities, fixed3 ambientBottom, fixed3 ambientTop)
{
	//Multiply sun color my intensity and ambient colour by density
	float4 result = float4(0, 0, 0, saturate(1 - transmittanceAndIntegratedIntensities.r));

	fixed3 sunColor = _LightColor0;
#if UNITY_COLORSPACE_GAMMA
	sunColor.rgb = GammaToLinearSpace(sunColor.rgb);
#endif
	result.rgb += transmittanceAndIntegratedIntensities.g * sunColor;

	result.rgb += transmittanceAndIntegratedIntensities.b * ambientBottom;
	result.rgb += transmittanceAndIntegratedIntensities.a * ambientTop;

	return result;
}

#endif // VCT_RAYMARCH_COLOR_INCLUDED