# Cloud Density

## Overview

We want to approximate a fully three-dimensional representation of the density
of the clouds at all points in space.

We can roughly break this up into the five following steps:

*Coverage*
* Determine at what height in the atmosphere we expect to see clouds. We can
parameterize types of clouds based on how high they are found in the atmosphere.
* Determine the horizontal cloud coverage based on a simulation or approximation
of the weather. We will try to expose this as an authorable coverage
texture.

*Local Density*
* Where we do have cloud coverage, determine the rough cloud density that will
achieve the desired cloud shape.
We will wish to parametrize this based on type.
* Determine the detailed cloud density, particularly for evaluating shape and
lighting at the surface.
* Determine the time evolution of the rough and detailed cloud densities.

## Common Operations

### Remap

The Remap function is a simple linear operation used to map a value or set of
values to a new range:
````
Remap(Value, OldMin, OldMax, NewMin, NewMax) = NewMin + (Value - OldMin) * (NewMax - NewMin) / (OldMax - OldMin)
````

In simple usage, while `Value` is a variable, while the old and new min and max
values are taken constant, so Remap just scales and offsets `Value`.

In our usage, one of the range values is also a variable. In this way, we can
use a different noise value to modulate an original noise used in `Value`.

_Example_

Frequently, the Remap function is used to 'trim away' the edges of a base function
through modulation with a higher-frequency detail function:
`Remap(Base, Detail, 1, 0, 1)`. Parts where the base function is close to the
maximum of 1 are unaffected by this remapping, since original values of 1 are
remapped to 1. Parts where the base function are smaller, however, will be
shrunk based on the value of the detail function. Let's visualize this in a
simple 2D example.

![Small Remapping](Docs/Remap_Small.png "Small Remapping")

With a small detail function (in grey), the base function (in red) is relatively
unchanged when its value is large, and only when its value is small do we see
the remapped result (in blue) responding to the detail function instead.

![Large Remapping](Docs/Remap_Large.png "Large Remapping")

With a large detail function, the effect is more pronounced. The effect of the
detail function in the remapping is seen when the base function value is small --
namely, at the edges of the peaks.

The remap function, along with a clamped version (restricting the final value
between NewMin and NewMax) are implemented for use in our shaders in
`MathUtil.cginc`.

### Other

TODO - others common operations


## Local Density

### Base Density

We can build on the large body of work that has been done in modelling cloud
density by procedural noise textures. In particular, we will consider the
"Physically Based Sky, Atmosphere and Cloud Rendering in Frostbite" presentation
from SIGGRAPH 2016 Course:
[Physically Based Shading in Theory and Practice](https://blog.selfshadow.com/publications/s2016-shading-course/).

The authors have released a C++ project
[TileableVolumeNoise](https://github.com/sebh/TileableVolumeNoise) that can
help generate the types of tileable, three-dimensional noise textures that can
be used to represent cloud density. We will use my
[fork](https://github.com/TylerDodds/TileableVolumeNoise/tree/feature/premultiplied-alpha),
which ensures that
the default outputs do not have incorrect pre-multiplied alpha processing,
so that all four channels of the texture (RGBA) will be imported into Unity
as expected. These textures are generated as long strips of 2D images, so
we will need additional work to bring them into Unity as `Texture3D`.
See the [NoiseTextures](NoiseTextures/NoiseTextures.md) page for details on how
to process and unpack all four channels of this texture to obtain the base
density.

See the [Cloud Coverage](#cloud-coverage) section for information on how we
approximate the effect of weather on this noise-based density before
determining the detail density.

### Detail Density

TODO

### Curl Offset

TODO

## Weather

At an even larger scale than the cloud [base density](#base-density), we provide
an additional user-generated texture that describes the large-scale weather
conditions. In principle, this is a texture that could be updated in real time
based on a weather simulation, but for simplicity we will consider textures
we can easily author ourselves in any image editing program.

The weather texture will describe the changing weather conditions horizontally,
so we will use the x and z coordinates at any given raymarch point to look up
the weather values from the texture.

The weather texture will hold the following three values, packed into the R, G
and B channels, respectively:

* Coverage: the fraction of full cloud coverage, affecting the base density.
* Wetness: the fraction of full wetness, affecting the lighting.
* Type: parametrizes different cloud shapes, particularly their vertical density
profile. Ranges from 0 to 1.



TODO

## Cloud Coverage

### Atmosphere

We assume that clouds exist only within some vertical slab within the atmosphere,
so their density is zero elsewhere. We can therefore perform raymarching only
within these extents; see the [Raymarching](../Raymarching/Raymarching.md) page
for details.

### Wind

We approximate the effect of wind during raymarching by sampling the density
from a world-space coordinate that has been shifted by the wind strength,
proportional to the time.

We also skew this coordinate further in the direction of the wind the higher
it is, to approximate how clouds are observed to be affected by the wind.
See this presentation on the
[Nubis system](https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine)
for details.

### Weather Coverage

After taking into account atmosphere, wind, and [height coverage](#height-coverage),
the base density is modified by the coverage value determined in the
[Weather](#weather) section.

We will mostly be considering the 'not covered' value, `1 - coverage`, since
when coverage is 1 we will leave the base density as it is.  
There are many ways we could apply this coverage value.
One would be to use the `Remap` function:
`Remap(density, 1 - coverage, 1, 0, 1)`. This would map the maximum density down
to the value of `1 - coverage`.

In our case, we will simply subtract: `density - (1 - coverage)`. One of the
advantages will be that a negative density can help signal to the raymarching
that it may begin to take larger steps. We can see the difference between these
two approaches in the plot below, with the density in grey, coverage in red,
remapped in green and subtracted in blue:

![Cloud Coverage Density](Docs/CloudCoverageDensity.png "Cloud Coverage Density")

The main difference is that the remapped version keeps the same peaks of the
original density, while the subtracted version more uniformly follows the
amount of coverage.

Another visual effect we parametrize is to multiply the density by the coverage,
which makes edges of the cloud wispier and tends to lighten them.

TODO

## Height

### Height Coverage

TODO

### Height Erosion

TODO

## Final Density

TODO
