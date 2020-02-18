#if !defined(VCT_NOISE_TEXTURE_UTIL_INCLUDED)
#define VCT_NOISE_TEXTURE_UTIL_INCLUDED

#include "MathUtil.cginc"

/// Each channel contains successively-high summed-octave-noise frequency,
/// in this case Worley noise. We take a linear combination,
/// with more weight to the lower-frequency noise.
float UnpackOctaves(float3 packed)
{
	return (packed.r * .625) + (packed.g * 0.25) + (packed.b * 0.125);
}

/// Remap a Perlin-Worley noise (in R channel) with mutliple octaves of fractal Worly noise (in GBA channels)
/// to create the base cloud density volume noise.
/// Add additional density offset to the Perlin-Worley noise before remapping to uniformly increase or decrease the density.
float UnpackPerlinWorleyBaseNoise(half4 baseNoiseValue, float densityOffset)
{
	baseNoiseValue.r = max(0, baseNoiseValue.r - densityOffset) / (1 - densityOffset);
	float lowFrequencyWorleyFractal = UnpackOctaves(baseNoiseValue.gba);
	float density = RemapClamped(baseNoiseValue.r, 1 - lowFrequencyWorleyFractal, 1.0, 0.0, 1.0);
	return density;
}

#endif // VCT_NOISE_TEXTURE_UTIL_INCLUDED