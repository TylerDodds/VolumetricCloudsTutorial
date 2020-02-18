#if !defined(VCT_RAYMARCH_INTERVAL_INCLUDED)
#define VCT_RAYMARCH_INTERVAL_INCLUDED

#include "CloudConstants.cginc"

#if defined(QUALITY_HIGH)
#define TARGET_STEP_SIZE 50
#define MIN_NUM_STEPS 256
#define MAX_NUM_STEPS 256
#elif defined(QUALITY_LOW)
#define TARGET_STEP_SIZE 50
#define MIN_NUM_STEPS 16
#define MAX_NUM_STEPS 16
#else 
#define TARGET_STEP_SIZE 50
#define MIN_NUM_STEPS 64
#define MAX_NUM_STEPS 64
#endif

int GetNumberOfSteps(float distance, float3 worldMarchDirection)
{
	int numSteps = distance / TARGET_STEP_SIZE;
	return min(max(numSteps, MIN_NUM_STEPS), MAX_NUM_STEPS);
}

bool GetCloudRaymarchInterval_Flat(float3 viewRayStart, float3 viewRayDirection, out float3 raymarchStart, out float raymarchDistance, out float distanceToTarget)
{
	float targetHeight = clamp(viewRayStart.y, cloudHeight, cloudHeight + cloudSlabHeight);
	float targetDifference = targetHeight - viewRayStart.y;
	distanceToTarget = targetDifference / viewRayDirection.y;
	raymarchStart = viewRayStart + distanceToTarget * viewRayDirection;
	float slabMarchEndHeight = cloudHeight + (viewRayDirection.y > 0 ? cloudSlabHeight : 0);//TODO optimize this instruction set?
	raymarchDistance = (slabMarchEndHeight - raymarchStart.y) / viewRayDirection.y;

	bool inInterval = (sign(distanceToTarget) < 0 || distanceToTarget > fadeMaxDistance);
	raymarchDistance = min(raymarchDistance, maxRaymarchDistance);
	return inInterval;
}

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
		//Must be inside atmosphere
		distanceToTarget = max(outer_t1, 0);
		raymarchDistance = outer_t2 - distanceToTarget;
	}

	raymarchDistance = min(raymarchDistance, maxRaymarchDistance);
	raymarchStart = viewRayStart + distanceToTarget * viewRayDirection;
	return true;
}

#endif // VCT_RAYMARCH_INTERVAL_INCLUDED