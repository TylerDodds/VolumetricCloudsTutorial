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
then we know it is pointing below the horizon.
As discussed in [Raymarch Fading](#raymarch-fading), we will have no clouds for
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
[Line-Plane Intersection](https://en.wikipedia.org/wiki/Line%E2%80%93plane_intersection)
with two vertical planes (normal vector along `y`) representing the bottom and
top of the slab. Based on the sign of the y-component of the view
direction, we know which plane we expect to hit first.

We take the maximum of 0 and the distance to this plane to get the distance
along the view direction to the start of our raymarch. Then by finding the
distance of the second plane from this starting position, we determine the
distance we need to raymarch. If this is negative, then the ray does not hit
the atmosphere.

#### `GetRaySphereIntersection(float3 rayPosition, float3 rayDirection, float3 sphereCenter, float radius, ...)`

Determines if the ray intersects the sphere, and the two distances along the ray
(in order) where the intersection occurs. Except for the edge case when the ray
skims the edge of the sphere, these will be different.

This is essentially
[Line-Sphere Intersection](https://en.wikipedia.org/wiki/Line%E2%80%93sphere_intersection),
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

Otherwise, if the ray does not intersect with the inner sphere, then the ray must
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

### Raymarch Fading

Raymarching is expensive. The more pixels we need to do raymarching for, and
the further distance we need to raymarch for, the longer it will take.

First, we will not perform raymarching if the view direction is below the
horizontal in world space. For most game level designs, this will be a safe
assumption: looking directly down, the player will be looking into the ground or
floor, and at the horizon there will be other elements in the distance
(buildings, hills, etc) to cover up the clouds there.

We will begin fading out the clouds when the view vector is horizontal, and stop
performing raymarching  completely at some small angle below that. Recall that
these  clouds will be far away due to the Earth's curvature, so the effect is to
fade out clouds based on distance.

Additionally, we will only perform raymarching up to a certain distance from the
beginning of the atmosphere. Otherwise, we are faced with the choice to keep the
step size the  same (leading to more steps and longer execution time), or keep
the maximum step size (leading to larger steps and poorer quality).
By taking `raymarchDistance = min(raymarchDistance, maxRaymarchDistance)`, we
can keep the step size and number under control.

We note again that this scenario is most prevalent near the horizon, where we
are looking through a larger portion of the atmosphere than looking
straight up. For such far-away clouds, capturing the closer-by portion is
good enough.

## Raymarching Math (`RaymarchIntegral.cginc`)

### Transmittance and Scattering Overview

We are interested in determining what happens to light as it passes through the
clouds, which is termed as
[participating media](http://old.cescg.org/CESCG-2000/SMaierhofer/node6.html).
Namely, it is a volume through which light is either absorbed, transmitted, or
scattered.

For each of these processes, we will be concerned with determining the
appropriate associated quantity. In this situation, these quantities are all
with reference to a particular volume (or sub-volume) of cloud, and are often
determined for light passing between to or from a particular point inside the
volume.

* [Transmittance](https://en.wikipedia.org/wiki/Transmittance):
the fraction of incident light that is transmitted.
* [Scattering](https://en.wikipedia.org/wiki/Scattering):
the fraction of light that is absorbed and re-emitted in a different directions
(depends on initial and final light direction).
* [Absorption](https://en.wikipedia.org/wiki/Absorption_(electromagnetic_radiation)):
the fraction of incident light that is taken up by the medium without re-emission.

We note that both scattering and absorption are both responsible for the
[_attenuation_](https://en.wikipedia.org/wiki/Attenuation) or _extinction_ of
light. All of these fractions, defined over the same volume, add to 1; in
particular, transmittance and attenuation add to 1.

Clouds are a special case where the scattering is so high that we can assume
that all of the attenuation comes from scattering, and ignore the amount coming
from absorption.

For each step in the raymarching, we need to determine at that point:
1. The transmittance of light coming from the sun arriving at that point.
2. The scattering of that light from the sun to the direction of the camera.
3. The transmittance of that remaining light from that point to the camera.

We note that steps 1 and 3 involve the same calculation for transmittance.

### Determining Transmittance

The [Beer-Lambert](https://en.wikipedia.org/wiki/Beer%E2%80%93Lambert_law)
can be used to determine the attenuation (equivalently, the transmittance) of
light through a material.

The transmittance T = exp(-&tau;), where &tau; is the _optical depth_
&int;<sub>0</sub><sup>L</sup>&sigma;(z)dz. The integral is performed over the
line for which the transmittance is calculated.

The _attenuation coefficient_ &sigma; is something we'll be parametrizing,
rather than attempting to determine from measured values. Since the scattering
and absorption within a cloud is due to the density of particles within the
cloud, &sigma; will be proportional to the cloud density &rho;:
&sigma;(z) = &rho;(z) * &sigma;<sub>E</sub>. Here, we'll parametrize the
_extinction coefficient_ &sigma;<sub>E</sub>. We'll note that units of &sigma;
should be 1 / meters so that the optical depth is unitless, so that
&sigma;<sub>E</sub> is a
[mass attenuation coefficient](https://en.wikipedia.org/wiki/Mass_attenuation_coefficient)
with units m^2 / kg.

However, when we consider the cloud density (see
[CloudDensity](../CloudDensity.md)) and &sigma;<sub>E</sub> values, we will be
ignoring these units, and consider cloud density to range from 0 to 1. We will
then parameterize &sigma;<sub>E</sub> to achieve clouds with the desired look.

### Raymarch Loop

#### Transmittance

We note that the full transmittance
T = exp(-&int;<sub>0</sub><sup>L</sup>&sigma;(z)dz).
We can divide the integral into portions:
&int;<sub>0</sub><sup>L</sup>&sigma;(z)dz =
&int;<sub>0</sub><sup>&Delta;z</sup>&sigma;(z)dz + ... +
&int;<sub>L - &Delta;z</sub><sup>L</sup>&sigma;(z)dz.

Thanks to [exponent laws](http://mathworld.wolfram.com/ExponentLaws.html),
the exponential of the sum of integrals becomes a product of exponential of
integrals:

exp(-&int;<sub>0</sub><sup>L</sup>&sigma;(z)dz) =
exp(-&int;<sub>0</sub><sup>&Delta;z</sup>&sigma;(z)dz) &Cross; ... &Cross;
exp(-&int;<sub>L-&Delta;z</sub><sup>L</sup>&sigma;(z)dz).

With this, we can see the structure of the raymarching loop. Each term in the
product is the transmittance of light through that portion of the ray, while the
_product_ of these terms, beginning from the left, determines the transmittance
from the beginning of the ray (z = 0).

A straightforward approximation to each individual transmittance term is to
consider &sigma;(z) (equivalently, the density)
to be constant over the interval &Delta;z of the integral;
for example,
exp(-&int;<sub>a</sub><sup>a+&Delta;z</sup>&sigma;(z)dz) &asymp;
exp(-&sigma;(a) &Delta;z) = exp(-&sigma;<sub>E</sub> &rho;(a) &Delta;z).

Therefore, at each step, we determine the transmittance at that step as above,
and can multiply it by the previous total transmittance to get the new total
transmittance after the step. This forms the core of the raymarching loop.

#### Scattering

Besides transmittance, the other quantity interested in is the total amount of
scattered light that will make it to the camera (equivalently, to the starting
point of the raymarching, since we begin where the clouds start).

Let's consider S(z) to be the amount of light scattered in the direction of the
camera at position z along the raymarch; see [Lighting](Lighting.md) for more
details. Then the total intensity is:

S<sub>TOT</sub> = &int;<sub>0</sub><sup>L</sup>S(z)T<sub>0&rarr;z</sub> dz.

We can also split this integral into steps:
S<sub>TOT</sub> = &int;<sub>0</sub><sup>&Delta;z</sup>S(z)T<sub>0&rarr;z</sub>dz +
... + &int;<sub>L-&Delta;z</sub><sup>L</sup>S(z)T<sub>0&rarr;z</sub>dz.

Let's consider one of the chunks in the middle:
S<sub>a</sub> = &int;<sub>a</sub><sup>a+&Delta;z</sup>S(z)T(z)dz, where T(z) is the
transmittance from 0 to z.
For a small step, we might consider approximating the integrand as constant,
giving S<sub>a</sub> &asymp; S(a)T(a)&Delta;z. This is called the _midpoint_ or
_rectangle_ rule in
[numerical integration](https://en.wikipedia.org/wiki/Numerical_integration),
and is the most straightforward, but poorest, method of approximation.
We may choose other integration methods (ways to split up and weight evaluation
of the integrand) that have higher accuracy.

However, as discussed in "Physically Based Sky, Atmosphere and Cloud Rendering
in Frostbite" [Appendix C](https://blog.selfshadow.com/publications/s2016-shading-course/),
this will not give an energy-conserving transmittance.
The best way to see this is to consider that the integrand changes as a function
of the depth z, even if we're assuming that the density is constant.
In this case, the scattering S(z), depending only on the density, is constant,
and we can approximate is as S(a). However, the transmittance is not:
T(z) = exp(-&int;<sub>0</sub><sup>a</sup>&sigma;(x)dx -
&int;<sub>a</sub><sup>z</sup>&sigma;(x)dx) for z between a and a+&Delta;z.
Then we can again use exponent rules, so
T(z) = T(a) &Cross; exp(-&int;<sub>a</sub><sup>z</sup>&sigma;(x)dx).
Since we've approximated with constant density, now &sigma;(x) can be approximated
as &sigma;(a), so T(z) &asymp; T(a) exp(-&int;<sub>a</sub><sup>z</sup>&sigma;(a)dx)
= T(a) exp(-&sigma;(a)(z-a)) = T(a) exp(a&sigma;(a)) exp(-z&sigma;(a)).
Most important to note is how this is exponentially decreasing with the distance
z, even assuming constant density.

Then S<sub>a</sub> &asymp;
&int;<sub>a</sub><sup>a+&Delta;z</sup> S(a) T(a) exp(a&sigma;(a)) exp(-z&sigma;(a)) dz
= [S(a) T(a) exp(a&sigma;(a))] &int;<sub>a</sub><sup>a+&Delta;z</sup> exp(-z&sigma;(a)) dz.
We can perform this integral of the exponential function analytically:
&int;<sub>a</sub><sup>a+&Delta;z</sup> exp(-z&sigma;(a)) dz =
[-exp(-z&sigma;(a))/&sigma;(a)]<sub>a</sub><sup>a+&Delta;z</sup> =
[exp(-a &sigma;(a)) - exp(-(&Delta;z+a)&sigma;(a))] / &sigma;(a).
Using exponent rules we pull out a constant factor:
exp(-a &sigma;(a))[1 - exp(-&sigma;(a)&Delta;z)] / &sigma;(a).

Adding this to our previous approximation to S<sub>a</sub>, we have
S(a) T(a) exp(a&sigma;(a)) exp(-a&sigma;(a)) [1 - exp(-&sigma;(a)&Delta;z)] / &sigma;(a) =
S(a) T(a) [1 - exp(-&sigma;(a)&Delta;z)]  / &sigma;(a).

Note that we need to find -&sigma;(a)&Delta;z to update transmittance, and we
have stored the previous value of T(a) from the last raymarch step, so to
perform this approximation, we need only evaluate S(a)
(see [Lighting](Lighting.md)).

#### Density vs. Opacity

In other raymarching contexts, instead of sampling the _density_ of the medium,
as we do here, instead what may be sampled is the color directly. In this case,
the transmittance of each step is determined directly from the sampled opacity.
This style of raymarching is often used to visualize volumetric data set.

Recall from [Transmittance](#transmittance) that the transmittance through
one raymarch step of size &Delta;z is exp(-&sigma;(a) &Delta;z).
The opacity of the step is 1 - transmittance, the fraction of light that doesn't
pass through from the background. Imagining a case of constant extinction coefficient
&sigma;(z) and constant step size &Delta;z, the transmittance of each step is
also constant, but depends on the step size we've chosen. In the similar case
where we are given the (constant) opacity instead of extinction coefficient,
the transmittance of each step must also depend on the chosen step size.

Therefore, when one is sampling opacity values, there must also be a constant
_reference length_ R<sub>L</sub> that determines the sampling rate corresponding
to the opacity.

Consider a sampled opacity value o, so 1 - o = t, the sampled transmittance,
where the step size is the reference length.
t = exp(-&sigma; R<sub>L</sub>). Then over this step,
&sigma; = - ln(t) R<sub>L</sub>.
Imagining we've sampled over some other step size &Delta;z, the transmittance
with the equivalent extinction coefficient is
exp(-&sigma; &Delta;z) = exp(-&sigma; R<sub>L</sub> (&Delta;z/R<sub>L</sub>)).
Using the exponent power rule, this is
exp(-&sigma; R<sub>L</sub>)<sup>(&Delta;z/R<sub>L</sub>)</sup>
= t<sup>(&Delta;z/R<sub>L</sub>)</sup>.

So, for sampled opacity values o, after correcting for step size,
o = 1 - (1 - o)<sup>(&Delta;z/R<sub>L</sub>)</sup>.

#### Steps

Starting at the initial raymarching position, we take steps in the raymarching
direction as discussed in raymarching [setup](#setup). Given the known distance,
we can determine a uniform step size. However, we may also choose to take
larger steps in cases where the density is smaller, the transmittance is
close to 1 through this portion, and the scattered light intensity is low,
so we can afford more approximate calculations.

TODO

### RaymarchTransmittanceAndIntegratedIntensityAndDepth

Input Parameters:

* `float3 raymarchStart`: Starting position of raymarching in world space
* `float3 worldDirection`: Direction of raymarching in world space
* `float distance`: Distance to perform raymarching for
* `float3 startPos`: Starting position of ray from camera (for depth calculation)
* `float offset`: Initial offset of raymarching along the raymarch direction.
This is left configurable and different from `raymarchStart` so that it can be
used to define a per-pixel offset later.

Output:

Returns a `float4` that contains packed values in the four channels:

* `r`: The transmittance of light coming from the _end_ of the raymarching to
the camera. If the transmittance of the fraction of this background light making
it through the cloud to the camera, then (1 - Transmittance) is the _opacity_
(or alpha value) of the pixel.
* `g`: The total intensity of light scattered from the sun through all points
to the camera. Ignoring atmospheric effects, the sun light will be all of one
color, so we need only to track the total intensity.
* `b`: The total intensity of _ambient_ light scattered through all points
to the camera.
* `a`: An estimate for the average depth of the clouds from the camera. This
can be used as a rough estimate to determine a 3D of the clouds along the
view ray.

In addition to integrating the sun light scattering intensity, we do the same for
ambient light intensity. Since we are only performing a single-scattering
approximation for the sun's light, we need to take additional steps to
recover the desired lighting look (see [Lighting](Lighting.md)).

Finally, at each step we find the distance of that point from the camera,
and add it to a weighted average depth. The weight is proportional to
(1 - Transmittance) for that step, so we calculate something like a 'center of mass'
or 'center of opacity' for the clouds along this direction. We'll use this if
we need to choose a single point along this ray where we consider the clouds to
be centered.
