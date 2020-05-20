#if !defined(VCT_CLOUD_CONSTANTS_INCLUDED)
#define VCT_CLOUD_CONSTANTS_INCLUDED

/// Height of the clouds bottom
static const float cloudHeight = 1500;
/// Total height of the clouds from bottom to top
static const float cloudSlabHeight = 3500;

/// Begin to fade out clouds at this distance
static const float fadeMinDistance = 10000;
/// Completely fade out clouds at this distance
static const float fadeMaxDistance = 20000;
/// Fade out clouds from this angle below the horizon
static const float fadeHorizonAngle = 0.01;

/// Do not raymarch more than this distance, even if it doesn't get through all the of atmosphere
static const float maxRaymarchDistance = 20000;

/// Effective earth radius
static const float earthRadius = 200000;//6371000 is the correct value, though smaller values can produce more compelling results
/// 3D position of earth center relative to Unity origin, based on effective earth radius
static const float3 earthCenter = float3(0, -earthRadius, 0);

/// Effective 'far' depth to use for return depth of clouds in directions where you see no clouds
static const float _farDepth = 1e6;

/// Maximum value of detail density to remap to zero
static const float _maxDetailRemapping = 0.8;

float GetHorizonFadeFactor(float3 worldSpaceRaymarchDirection)
{
	return (1 - smoothstep(0, -fadeHorizonAngle, worldSpaceRaymarchDirection.y));
}

#endif // VCT_CLOUD_CONSTANTS_INCLUDED