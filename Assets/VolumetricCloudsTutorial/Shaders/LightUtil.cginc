#if !defined(VCT_LIGHT_UTIL_INCLUDED)
#define VCT_LIGHT_UTIL_INCLUDED

#include "Lighting.cginc"
///Direction "towards" the directional light, in world space.
inline float3 GetWorldSpaceLightDirection()
{
	//By inspection, within our post-processing script, this takes the value of the light used for the sun source
	//(whether explicitly set in lighting settings or not)
	return _WorldSpaceLightPos0.xyz;
}

///Full Henyey-Greenstein phase function
float HenyeyGreenstein(float cosTheta, float g)
{
	float gSquared = g * g;
	float prefactor = (1.5 / _four_pi) * (1.0 - gSquared) / (2.0 + gSquared);
	return prefactor * (1.0 + cosTheta * cosTheta) / pow(abs(1.0 + gSquared - 2.0 * g * cosTheta), 1.5);
}

///Pseudo-Henyey-Greenstein phase function
float HenyeyGreensteinApproximation(float cosTheta, float g)
{
	float gSquared = g * g;
	float approx = ((1.5) * (1 - gSquared) * (1 + cosTheta * cosTheta) / ((2 + gSquared) * (1 + gSquared - 2 * g * cosTheta)) + g * cosTheta);
	return max(0, approx / _four_pi);
}

///Schlick approximation to Pseudo-Henyey-Greenstein phase function
float HenyeyGreensteinSchlick(float cosTheta, float g)
{
	float k = 1.55 * g - 0.55 * g * g * g;
	float angFac = 1 + k * cosTheta;
	return (1 - (k * k)) / (angFac * angFac * _four_pi);
}

float PhaseFunction(float cosTheta, float g)
{
	return HenyeyGreenstein(cosTheta, g);
}

///Exponential integral function (see https://mathworld.wolfram.com/ExponentialIntegral.html)
float ExponentialIntegral(float z)
{
	return 0.5772156649015328606065 + log(1e-4 + abs(z)) + z * (1.0 + z * (0.25 + z * ((1.0 / 18.0) + z * ((1.0 / 96.0) + z * (1.0 / 600.0)))));
}

///Approximation to ambient intensity assuming homogeneous radiance coming separately form top and bottom of clouds
///See Real-Time Volumetric Rendering course notes By Patapom / Bomb! 
float2 GetAmbientIntensityTopBottom(float heightFraction, float sigmaExtinction)
{
	float ambientTerm = -sigmaExtinction * saturate(1.0 - heightFraction);
	float isotropicScatteringTop = max(0.0, exp(ambientTerm) - ambientTerm * ExponentialIntegral(ambientTerm));

	ambientTerm = -sigmaExtinction * heightFraction;
	float isotropicScatteringBottom = max(0.0, exp(ambientTerm) - ambientTerm * ExponentialIntegral(ambientTerm));

	// Additional modulation
	isotropicScatteringTop *= saturate(heightFraction * 0.5);

	return float2(isotropicScatteringTop, isotropicScatteringBottom);
}

static const float _four_pi = 12.5663706144;

#endif // VCT_LIGHT_UTIL_INCLUDED