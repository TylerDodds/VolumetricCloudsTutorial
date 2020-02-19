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

TODO Linear01Depth?

If there is an object in front of the clouds, we ensure that the cloud fragment
is essentially empty: it has transmittance 1, intensity 0, and a far depth.

TODO

### Raymarch Extents

TODO

## Raymarching Math

TODO
