#if !defined(VCT_RAYMARCH_INTERVAL_INCLUDED)
#define VCT_RAYMARCH_INTERVAL_INCLUDED

#include "CloudConstants.cginc"

#if defined(QUALITY_EXTREME)
#define ADAPTIVE_FRACTION_DENSITY_INCREASING 4
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_LOCAL_MAXIMUM 6
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_MONOTONIC 8
#define TARGET_STEP_SIZE 120
#define MIN_NUM_STEPS 96
#define MAX_NUM_STEPS 128
#elif defined(QUALITY_HIGH)
#define ADAPTIVE_FRACTION_DENSITY_INCREASING 2
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_LOCAL_MAXIMUM 2.5
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_MONOTONIC 3
#define TARGET_STEP_SIZE 120
#define MIN_NUM_STEPS 48
#define MAX_NUM_STEPS 64
#elif defined(QUALITY_LOW)
#define ADAPTIVE_FRACTION_DENSITY_INCREASING 1
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_LOCAL_MAXIMUM 1.5
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_MONOTONIC 2
#define TARGET_STEP_SIZE 450
#define MIN_NUM_STEPS 12
#define MAX_NUM_STEPS 16
#else
#define ADAPTIVE_FRACTION_DENSITY_INCREASING 1.5
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_LOCAL_MAXIMUM 2
#define ADAPTIVE_FRACTION_DENSITY_DECREASING_MONOTONIC 2.5
#define TARGET_STEP_SIZE 220
#define MIN_NUM_STEPS 24
#define MAX_NUM_STEPS 32
#endif


/// Gets the number of steps based on TARGET_STEP_SIZE,
/// clamped between MIN_NUM_STEPS and MAX_NUM_STEPS.
int GetNumberOfSteps_Distance(float distance)
{
	int numSteps = distance / TARGET_STEP_SIZE;
	return min(max(numSteps, MIN_NUM_STEPS), MAX_NUM_STEPS);
}

/// Gets the number of steps between MIN_NUM_STEPS (vertical directions) and MAX_NUM_STEPS (horizontal directions).
int GetNumberOfSteps_Direction(float3 rayWorldDirection)
{
	return lerp(MAX_NUM_STEPS, MIN_NUM_STEPS, abs(rayWorldDirection.y));
}

/// Gets the number of steps based on distance and/or ray direction.
int GetNumberOfSteps(float distance, float3 rayWorldDirection)
{
	return GetNumberOfSteps_Direction(rayWorldDirection);
}

/// From a camera view ray, get the raymarch interval (start position, distance to raymarch, and distance to start position)
/// based on a flat slab of clouds (as though assuming world is flat).
bool GetCloudRaymarchInterval_Flat(float3 viewRayStart, float3 viewRayDirection, out float3 raymarchStart, out float raymarchDistance, out float distanceToTarget)
{
	float targetHeight = clamp(viewRayStart.y, cloudHeight, cloudHeight + cloudSlabHeight);
	float targetDifference = targetHeight - viewRayStart.y;
	distanceToTarget = max(0, targetDifference / viewRayDirection.y);
	raymarchStart = viewRayStart + distanceToTarget * viewRayDirection;
	float slabMarchEndHeight = cloudHeight + (viewRayDirection.y > 0 ? cloudSlabHeight : 0);
	raymarchDistance = (slabMarchEndHeight - raymarchStart.y) / viewRayDirection.y;

	bool inInterval = raymarchDistance > 0;
	raymarchDistance = min(raymarchDistance, maxRaymarchDistance);
	return inInterval;
}

/// Gets the intersection of a ray and a sphere, returning false if no intersection, and true if there is an intersection.
/// If true, t1 and t2 return the distances of the two intersection points along the ray, and may be negative
/// if the intersection happens behind the ray, but on the line that it defines.
bool GetRaySphereIntersection(float3 rayPosition, float3 rayDirection, float3 sphereCenter, float radius, out float t1, out float t2)
{
	float3 offset = rayPosition - sphereCenter;
	float b = dot(offset, rayDirection);
	float c = dot(offset, offset) - (radius * radius);

	float discriminant = b * b - c;
	if (discriminant >= 0.0)
	{
		t1 = -b - sqrt(discriminant);
		t2 = -b + sqrt(discriminant);
		return true;
	}
	return false;
}

/// From a camera view ray, get the raymarch interval (start position, distance to raymarch, and distance to start position)
/// based on a spherical slab of atmosphere.
bool GetCloudRaymarchInterval_EarthCurvature(float3 viewRayStart, float3 viewRayDirection, out float3 raymarchStart, out float raymarchDistance, out float distanceToTarget)
{
	float outer_t1, outer_t2, inner_t1, inner_t2;
	bool outerIntersected = GetRaySphereIntersection(viewRayStart, viewRayDirection, earthCenter, earthRadius + cloudHeight + cloudSlabHeight, outer_t1, outer_t2);
	if (!outerIntersected || outer_t2 < 0)
	{
		//Must be outside of the outer part of the spherical shell, so the ray won't intersect the shell at all, or only intersects behind the start of the ray.
		raymarchStart = viewRayStart;
		raymarchDistance = 0;
		distanceToTarget = 0;
		return false;
	}

	bool innerIntersected = GetRaySphereIntersection(viewRayStart, viewRayDirection, earthCenter, earthRadius + cloudHeight, inner_t1, inner_t2);

	if (innerIntersected)
	{
		if (inner_t1 < 0)
		{
			//In this case we have an intersection behind us, so we're inside the inner & outer spheres and we expect to see the spherical shell through the positive intersection.
			distanceToTarget = max(inner_t2, 0);
			raymarchDistance = outer_t2 - distanceToTarget;
		}
		else
		{
			//Here we have cases of being in or above the clouds. We just raymarch until the first intersection with the inner sphere, even if we'd re-enter the slab looking down elsewhere, because in most cases we'd still have the planet in the way before re-entering the spherical shell.
			if (outer_t1 < 0)
			{
				//As in the logic above, we're within the outer sphere (but in this case, not in the inner sphere) so within the clouds.
				distanceToTarget = 0;
				raymarchDistance = inner_t1;
			}
			else
			{
				//We're outside the slab now, so expect to intersect with outer shell first
				distanceToTarget = outer_t1;
				raymarchDistance = inner_t1 - outer_t1;
			}
		}
	}
	else
	{
		//Must be inside atmosphere or outside of it, where ray passes only through shell, not into inner sphere
		distanceToTarget = max(outer_t1, 0);
		raymarchDistance = outer_t2 - distanceToTarget;
	}

	raymarchDistance = min(raymarchDistance, maxRaymarchDistance);
	raymarchStart = viewRayStart + distanceToTarget * viewRayDirection;
	return true;
}

#endif // VCT_RAYMARCH_INTERVAL_INCLUDED
