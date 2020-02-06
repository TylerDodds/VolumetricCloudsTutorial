# Tutorial

## Overview & Goal

The goal of this tutorial is to render clouds as a volume of transparent media
within the atmosphere. The focus is on achieving a reasonable lighting, shape,
density, and real-time evolution of the clouds in an artist-controllable
fashion, not attempting an exact simulation.

For simplicity, we will limit our implementation to one where the clouds are
always the furthest semitransparent object rendered. Additionally, we will not
model atmospheric scattering effects of light passing from the clouds to the
camera.

## Prerequisites

TODO

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
1. We need to simulate or approximate a fully three-dimensional representation
of the density of the cloud at all points in space, since this is what will
control the absorption and scattering mentioned above.
2. At each pixel we view on the screen, we need to consider all of the
light that last got scattered by the cloud and ended up travelling to the
camera on the view vector associated with the pixel. This requires us to consider
all points along the view vector inside the cloud and determine how much of the
light scattered this way would make its way through the rest of the cloud
_without_ being scattered or absorbed.
3. We need to determine the probability that light will be absorbed or
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

To determine the lighting contribution at each raymarch step in (3), we will
first begin by considering light that has undergone scattering once from
its source (the sun). As noted previously, clouds are a somewhat special case
of volumetric rendering where multiple scattering events need to be simulated
to capture the proper light intensity.


TODO

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

### Noise Textures

TODO

## Components

TODO
