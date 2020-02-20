# Raymarching

## Overview

As mentioned in the [Tutorial](../Tutorial.md), to properly consider the
color of a cloud in a given view direction, we need to consider light that
scatters from all points inside the cloud that will lead back to the camera
along that view ray.

A straightforward way to tackle this is through _raymarching_, which consists of
taking small steps along the view vector from the camera.
At each step, we determine how much light will be scattered in the view vector
direction, and how much will make it to the camera. As we get further into the
cloud, less and less of the light from those points will make it to the camera,
meaning that the cloud gets more and more opaque.

## Raymarching Theory Basics

At each step, we determine the density of the cloud at that point, and use it
(along with the total density we've passed through so far) to determine the
fraction of light that would make it through the cloud back to the camera
(recall that some fraction will be absorbed or scattered, which we will consider
to be 'lost' for this view vector).

We will also determine the fraction of
sun light that (a) managed to make it to that point from the sun, and
(b) was scattered in the direction of the camera.

With this information, we keep a running tally of the _transmittance_
(fraction of light making it to the camera), and the _intensity_
(total amount of light that has made it to the camera).
We use the density to update the transmittance, and the light scattering
fraction to update the intensity.

## Setup

### From Fragment Shader (`FragmentRaymarching.cginc`)

#### `FragmentTransmittanceAndIntegratedIntensityAndDepth`

Input Parameters:

* `float2 uv_depth`: uv for performing depth texture lookup
* `float3 ray`: world-space view ray of the pixel (not normalized)
* `float offset`: raymarch position offset along the ray
* `sampler2D _CameraDepthTexture`: The depth texture

Output Parameters:

* `out float3 worldSpaceDirection`: normalized world-space direction of the view ray

Returns:

`float4` with transmittance in r, integrated sun intensity in g,
integrated ambient intensity in b, and average depth in a channels respectively.

In most rendering pipelines and pathways where we will be implementing volumetric
clouds, the camera's [depth texture](https://docs.unity3d.com/Manual/SL-DepthTextures.html)
will be made available separately by Unity after rendering opaque objects.

This function samples the depth texture to determine if an opaque objects exists
at finite depth, using the `SAMPLE_DEPTH_TEXTURE` macro from _UnityCG.cginc_.
As discussed in the [depth texture](https://docs.unity3d.com/Manual/SL-DepthTextures.html)
page, this is not the depth in meters, but a packed value ranging from 0-1 or
1-0, depending on the UNITY_REVERSED_Z
[preprocessor macro](https://docs.unity3d.com/Manual/SL-BuiltinMacros.html).

We can check for the existence of an object by checking the sample's value
against the largest possible depth value in this range.

By using `LinearEyeDepth(...)` we can determine the distance of the opaque
object, and use that to stop raymarching.

If there is an object in front of the clouds, we set the cloud fragment
to empty: it has transmittance 1, intensity 0, and a far depth.

Additionally, if the world-space direction of the view ray is negative in `y`,
then we know it is pointing below the horizon, so we will have no clouds for
this pixel, again setting the cloud fragment to empty.

Finally, we check the raymarch extents (discussed below) by determining where
the view ray intersects with the Earth's atmosphere. If a range exists in front
of the camera, we proceed to raymarching that range; otherwise, we set the cloud
fragment to empty.

### Raymarch Extents (`RaymarchInterval.cginc`)

We take in the view ray (starting position, and ray direction) and wish to
determine the distance along the ray where clouds begin, and the distance
along the ray where clouds end.

Then, the beginning of the raymarching happens at the position:
`viewRayStart + distanceToClouds * viewRayDirection`.

#### `GetNumberOfSteps(float distance)`

Gets the number of steps based on defined TARGET_STEP_SIZE variable, clamped
between MIN_NUM_STEPS and MAX_NUM_STEPS.

#### `GetCloudRaymarchInterval_Flat(float3 viewRayStart, float3 viewRayDirection, ...)`

Here, we represent the atmosphere as a horizontal slab of uniform height.

We perform simple
https://en.wikipedia.org/wiki/Line%E2%80%93plane_intersection[Line-Plane Intersection]
with two vertical planes (normal vector along `y`) representing the bottom and
top of the slab. Based on the sign of the y-component of the view
direction, we know which plane we expect to hit first.

TODO

#### `GetRaySphereIntersection(float3 rayPosition, float3 rayDirection, float3 sphereCenter, float radius, ...)`

Determines if the ray intersects the sphere, and the two distances along the ray
(in order) where the intersection occurs. Except for the edge case when the ray
skims the edge of the sphere, these will be different.

This is essentially
https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection[Line-Sphere Intersection],
but where the sign of the distances from the ray start position matters.

When both are negative, there is no intersection (ray is outside of the sphere
and pointing away). When one is negative and the other positive, the ray begins
inside the sphere and so must intersect it. When both are positive, the ray
begins outside of the sphere, pointing towards it.

#### `GetCloudRaymarchInterval_EarthCurvature(float3 viewRayStart, float3 viewRayDirection, ...)`

We represent the atmosphere as a spherical shell of uniform height.

We perform ray-sphere intersection to determine intersection of the view ray
with both spheres representing the inner and outer parts of the shell (bottom
and top of the atmosphere, respectively).

If the ray does not intersect with the outer sphere, or the intersection is
completely behind the ray (both distances negative), then the ray is completely
outside the atmosphere, pointing away, and does not intersect.

Otherwise, if the ray does intersect with the inner sphere, then the ray must
exit out of the outer sphere in front of it, _possibly_ also entering the outer
sphere first. We have the raymarch range as
`[max(0, intersection_1), intersection_2]`.

Lastly, we consider the cases where the ray intersects both spheres.
If the first intersection with the inner sphere is behind the ray, then we know
the ray starts inside both spheres (and so the first intersection with the outer
sphere is also behind the ray), so we raymarch in the range
`[max(inner_intersection_2, 0), outer_intersection_2]`.

Now, if the first intersection with the inner sphere is in _front_ of the ray,
then the ray begins in or above the clouds. If the first outer sphere intersection
is also in front of the ray, then we must be completely outside of the outer
sphere, with the ray pointing towards the inner sphere, intersecting both. The
range is `[outer_intersection_1, inner_intersection_1]`. If the first outer sphere
is behind the ray, then we are in the last remaining case: inside the slab,
pointing toward the inner sphere. The range is `[0,inner_intersection_1]`.

TODO

### Raymarch Fading

TODO

## Raymarching Math

TODO
