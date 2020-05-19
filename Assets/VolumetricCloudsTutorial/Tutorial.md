# Tutorial

## Overview & Goal

The goal of this tutorial is to render clouds as a volume of transparent media
within the atmosphere. The focus is on achieving a reasonable lighting, shape,
density, and real-time evolution of the clouds in an artist-controllable
fashion, not attempting an exact simulation.

For simplicity, we will limit our implementation to one where the clouds are
always the furthest object rendered. Additionally, we will not
model atmospheric scattering effects of light passing from the clouds to the
camera.

## Prerequisites

We'll be using Unity's default
[built-in render pipeline](https://docs.unity3d.com/Manual/built-in-render-pipeline.html),
using the [OnRenderImage](https://docs.unity3d.com/Manual/ExecutionOrder.html#Rendering)
callback to add clouds to the scene using post-processing.
Therefore, most version of Unity from 5.6 up to the latest (2019.3) should be
compatible.

We will also need the ability to compile and run C++ projects; we will use one
to pre-generate texture containing the procedural noise values we will use to
build up the clouds.

## Volumetric Rendering Overview

Unlike most objects drawn in real-time rendering applications, clouds are
transparent and do not have a well-defined surface. As a result, light will
pass into the interior of the cloud. Some of the light will hit the water
molecules that make up the cloud and get absorbed, while some will instead get
scattered in another direction. Clouds in particular have a high amount of this
type of scattering, so that once the light hits our eye/camera, it may have
scattered in different directions many times.

Since we need to consider what is happening at all points _inside_ the cloud,
we can break our task into three main pieces.
1. _Cloud Density_. We need to simulate or approximate a fully three-dimensional representation
of the density of the cloud at all points in space, since this is what will
control the absorption and scattering mentioned above.
2. _Raymarching_. At each pixel we view on the screen, we need to consider all of the
light that last got scattered by the cloud and ended up travelling to the
camera on the view vector associated with the pixel. This requires us to consider
all points along the view vector inside the cloud and determine how much of the
light scattered this way would make its way through the rest of the cloud
_without_ being scattered or absorbed.
3. _Lighting and Shadows_. We need to determine the probability that light will be absorbed or
scattered in different directions, depending on the density of the cloud.

For density determination in (1), we will take an approximate approach that will
give us flexibility in achieving different looks. We will take a similar
approach to that of
[Schneider and Vos](https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine),
where we build the density as a composite of a set of pre-generated 3D noise
textures. By varying the elements of the composition over time, we can simulate
wind and other changing aspects of the clouds.

To determine the total light contribution in (2), we perform
[_raymarching_](https://en.wikipedia.org/wiki/Volume_ray_casting)
through the clouds, determining the lighting contribution at many small,
successive steps and adding them up. To do this, we will write an image effect
that will evaluate a custom shader at every pixel on the screen, determine the
camera's view ray from that pixel, and perform raymarching through the portion
of the atmosphere where clouds occur.
See the [Raymarching page](Raymarching/Raymarching.md) for more details.

To determine the lighting contribution at each raymarch step in (3), we will
first begin by considering light that has undergone scattering _one_ time from
its source (the sun). As noted previously, clouds are a somewhat special case
of volumetric rendering where multiple scattering events need to be simulated
to capture the proper light intensity. Since this is computationally too
expensive to be performed in real-time, we will instead apply approximations and
alterations of the single-scattering lighting to roughly match the desired
visual look. At each point in the raymarch, we determine the fraction of sun
light intensity that has not been scattered or absorbed on its way to that point,
then the fraction of light that will be scattered in the direction of the camera,
then the fraction that will not be scattered or absorbed on its way out of the
cloud before it reaches the camera.
See the [Lighting page](Raymarching/Lighting.md) for more details.

## Project Set-Up

### Image Effects

We set up our Clouds rendering as a Unity Image Effect Component on the Camera
GameObject. See the [Image Effects page](ImageEffects/ImageEffects.md) for more
details.

This will allow our implementation to work across versions of Unity as old as
5.6. It can serve as a good starting point for use as a step in a scriptable
render pipeline, whether Universal, HDRP, or custom.

For similar compatibility reasons, we will keep our work within the Assets
folder. With the appropriate Assembly Definition Files and manifest, it could be
converted to the Unity Package Manager format.

### Shaders

TODO

### Noise and Lookup Textures

As discussed in the [Cloud Density](CloudDensity/CloudDensity.md) page, we
will have several pre-generated textures that parametrize the atmospheric cloud
coverage and cloud density. By using pre-generated textures where possible, we
gain in speed of texture lookup over performing similar calculations each frame
within the shader, and we help expose authorable textures to the user.

Such as set-up will be limited in its configurability, since we will be limited
to changing the textures or the relationships between them in the final
calculation. In considering future extensions to this approach, we could
update these textures occasionally in real time, either through CPU calculation
or GPU calculation (for instance, using compute shaders).

These textures will be a mixture of 2D and 3D. See the
[Noise Textures](CloudDensity/NoiseTextures/NoiseTextures.md) page for details
on how we will handle creation of Unity's `Texture3D` for the noise textures.

## Unity Components

TODO

## Rendering Pipeline

### Color Space

As discussed in [Lighting](Raymarching/Lighting.md), we should use a Linear
color space, instead of a Gamma one.

### Antialiasing

Our image effects rely on knowing the scene depth. As a result, it shares a
similar [downside to deferred rendering](https://en.wikipedia.org/wiki/Deferred_shading)
in that the [resolved camera depth texture](https://docs.unity3d.com/Manual/SL-DepthTextures.html)
we can access in shaders will not match pixels on the edges of objects
when [MSAA](https://docs.unity3d.com/ScriptReference/Camera-allowMSAA.html) is enabled.
Therefore, while this effect does not particularly require
either Forward or Deferred render paths, it is more compatible with the Deferred path.

### Depth

As discussed in [History](Raymarching/History.md), there will be cases where we
need to look up raymarch results from pixels that would lie behind opaque objects
in the scene, particularly those at the edge of objects. While Unity's
[depth texture](https://docs.unity3d.com/Manual/SL-DepthTextures.html)
can tell us which pixels are covered by opaque objects, we would need to
determine from this the minimum depth of each pixel's neighbours (perhaps
several pixels distant) to determine this.

However, when considering a full pipeline, there will be many effects that may
wish to transform the base depth texture. A
[hierarchy](https://miketuritzin.com/post/hierarchical-depth-buffers/)
of depth textures may be useful for faster lookup, for example.
As a result, we will consider any such transformations out of scope of this
project. We note that, particularly if there is significant coverage of
geometry above the horizon, where raymarch distances are longest,
it could be worth it to perform this local minimum depth transformation and
skip raymarching where it's not needed, particularly if the geometry is static.

Similarly, due to considerations in our [History](Raymarching/History.md)-based
implementation, we will not consider the case where clouds may be in front
of objects -- opaque or otherwise. While we may handle opaque objects by
raymarching only to the distance indicated by the scene's depth at each pixel,
moving objects will create visual artifacts as the historical results no
longer reflect the appropriate cloud distance.
Objects with transparency introduce sorting issue that would
need to be handled by including the clouds in a completely different place in the
rendering pipeline.

## Tutorial Reading

This tutorial has linked to many other Markdown files discussing different
components of cloud rendering. A suggested reading order might be as follows:

* Tutorial
  * This page gives a high-level overview of cloud rendering, project setup and scope.
* [Image Effects](ImageEffects/ImageEffects.md)
  * Discusses the basic setup we will use to perform cloud rendering using our
  custom image effects via the `OnRenderImage` callback.
* [Cloud Density](CloudDensity/CloudDensity.md)
  * Discusses the hierarchical steps we will take to build a representation of
  the three-dimensional cloud density function that we will sample in our
  shaders.
* [Noise Textures](CloudDensity/NoiseTextures/NoiseTextures.md)
  * Discusses specifics of the generation and packing of the noise textures
  used to build up the cloud density.
* [Raymarching](Raymarching/Raymarching.md)
  * Discusses how step-by-step raymarching samples the cloud density and
  builds up the profile of light transmittance and scattering.
* [Lighting](Raymarching/Lighting.md)
  * Discusses scattering of directional light from the sun, self-shadowing of this
  light as it initially passes through clouds,
  and ambient lighting approximations.
* [History](Raymarching/History.md)
  * Discusses how to combine previous frames' raymarching results to mitigate
  issues from large raymarching step sizes.
