#if !defined(VCT_CLOUD_DENSITY_INCLUDED)
#define VCT_CLOUD_DENSITY_INCLUDED

#include "NoiseTextureUtil.cginc"

uniform sampler3D _BaseDensityNoise;

uniform float _CloudScale = 1;
uniform float _WeatherScale = 1;
uniform float _BaseDensityTiling = 1;
uniform float _CloudDensityOffset = 0;
uniform float4 _WindStrengthAndSkew = float4(0, 0, 0, 0);
uniform float _CloudDensityCoverageMultiplier = 1;

uniform sampler2D _WeatherTex;

/// Determines the fraction within the atmosphere's height,
/// given a height value.
float HeightFraction(float effectiveVerticalHeight)
{
	return saturate((effectiveVerticalHeight - cloudHeight) / cloudSlabHeight);
}

/// Determines the fraction within the atmosphere's height,
/// given a world-space position, 
/// assuming a shell that is not perfectly spherical, 
/// instead of constant vertical height.
float HeightFractionCylindrical(float3 worldPos)
{
	float cylindricalRadiusSquared = dot(worldPos.xz, worldPos.xz);
	float additionalEffectiveHeightFromCylindricalDistance = earthRadius - sqrt(max(0, earthRadius * earthRadius - cylindricalRadiusSquared));
	return HeightFraction(worldPos.y + additionalEffectiveHeightFromCylindricalDistance);
}

/// Determines the fraction within the atmosphere's height,
/// given a world-space position, 
/// assuming a perfectly spherical shell based on earth center and radius.
float HeightFractionSpherical(float3 worldPos)
{
	float sphericalRadius = length(worldPos - earthCenter) - earthRadius;
	return HeightFraction(sphericalRadius);
}

/// Determines the fraction within the atmosphere's height given a world-space position.
float HeightFraction(float3 worldPos)
{
	return HeightFractionCylindrical(worldPos);
}

/// Determines the distance fraction between the minimum and maximum fade distances
float DistanceFraction(float3 worldPos)
{
	float distance = length(worldPos.xz);
	return saturate((distance - fadeMinDistance) / fadeMaxDistance);
}

/// Determines effective position to sample a cloud from, given initial world position and height fraction within cloud atmosphere.
float3 ApplyWind(float3 worldPos, float heightFraction)
{
	// We also skew clouds in the direction of the wind the higher they are
	worldPos.xz -= heightFraction * _WindStrengthAndSkew.xz * _WindStrengthAndSkew.w;
	worldPos.xyz -= _WindStrengthAndSkew.xyz * _Time.y;
	return worldPos;
}

/// Applies cloud coverage to base density
float DensityWithCoverage(float density, float coverage)
{
	density = density - (1 - coverage);
	density *= lerp(1, coverage, _CloudDensityCoverageMultiplier * step(0, density));//Makes edges of the cloud wispier and tends to lighten them, also
	return density;
}

float GetBaseDensity(float3 pos, int lod, out float wetness, out float3 animatedPos, out float heightFraction, out float erosion)
{
	float3 posBeforeAnimation = pos;

	float distanceFraction = DistanceFraction(posBeforeAnimation);
	heightFraction = HeightFraction(posBeforeAnimation);
	if (heightFraction < 0 || heightFraction > 1 || distanceFraction >= 1)
	{
		wetness = 0;
		animatedPos = pos;
		erosion = 0;
		return 0;
	}

	animatedPos = ApplyWind(posBeforeAnimation, heightFraction);

	//Get weather data.
	//TODO get weather data: coverage, wetness, cloud type, density and erosion

	float4 weatherUV = float4(0.5 + posBeforeAnimation.xz / _WeatherScale, 0, 0);
	float3 cloudCoverageWetnessType = tex2Dlod(_WeatherTex, weatherUV);

	float3 baseUv = animatedPos / _CloudScale * _BaseDensityTiling;
	float4 baseNoiseValue = tex3Dlod(_BaseDensityNoise, float4(baseUv, 0));
	float density = UnpackPerlinWorleyBaseNoise(baseNoiseValue, _CloudDensityOffset);

	//TODO apply weather density, coverage, and erosion
	erosion = 0;
	float coverage = 1;//TODO

	density = DensityWithCoverage(density, coverage);

	density *= 0.001;//TODO until rest of density & lighting calculations are performed, use a lower base density so clouds are not effectively opaque

	return density;
}

float GetDetailDensity(float3 posBase, float3 animatedPos, float heightFraction, int lod, float baseDensity, float erosion)
{
	//TODO get detail density
	return baseDensity;
}

#endif // VCT_CLOUD_DENSITY_INCLUDED