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

We will use the [`Remap`](#remap) operation exactly as discussed in the example,
to combine the base density with a higher-frequency detail density:
`RemapClamped(baseDensity, detailAmount, 1, 0, 1)`.

The detail density itself consists of 3D fractal Worley noise; see the
[NoiseTextures](NoiseTextures/NoiseTextures.md) page for details.
We'll multiply by parametrized detail strength factor to keep the remapping from
significantly decreasing the overall density too much:
` detailAmount = min(maxDetailRemapping, detailFactor * detailStrength)`.
We also include the maximum value `maxDetailRemapping` (of around 0.8) to
keep a band of base density that will never be fully remapped to zero.

### Curl Offset

We'll apply an offset to the position where the detail density noise texture
lookup is performed, to add an extra bit of wispiness and detail to the
cloud edges.

One popular way to perform such offset lookups is to model a
[flow field](https://en.wikipedia.org/wiki/Vector_field#Flow_curves) describing
the speed of flow throughout space. We'll again use a lookup texture for this,
but only a 2D one (ignoring the height variable).

Such flow fields can be represented by
[divergence-free vector fields](https://en.wikipedia.org/wiki/Solenoidal_vector_field),
where the change of the field coming _into_ the point is the same as the change
coming _out_ of the point. We can achieve such a field by taking the
[curl](https://en.wikipedia.org/wiki/Curl_(mathematics)) of another vector field.
Such _curl noise_ is used in games to map all kinds of fluid flow.
See the [NoiseTextures](NoiseTextures/NoiseTextures.md) page for details.

We need to support a `TextureFormat` of `RGFloat` (two channels,
floating-point precision) or `RGB24` (three channels are used, 8 bits per channel).
In the latter case, the values will be encoded from the range [-1, 1] to [0, 1], so we'll have to
decode the three channels.

When setting the curl texture in the material, we also set the `UNPACK_CURL`
keyword if the texture format is 8 bits per channel, instead of floating point.
We enable this in the shader `CGPROGRAM` block with the line
`#pragma shader_feature UNPACK_CURL`,
and can test in the shader program with the shader preprocessor macro
````
#if defined(UNPACK_CURL)
...
#endif
````

Then we add the curl noise value, multiplied by strength, to the world-space
position where the detail density noise texture will be evaluated. We also
decrease the effect of the curl with height, to make a more pronounced
effect on the bottom of the clouds.

## Weather

### Weather Texture

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

Some rough examples are available in the `WeatherTexture` folder, having been
assembled with various noise patterns for each channel. They may be handcrafted
to better achieve a particular look.

### Coverage Modifications

We parametrize a multiplier fraction and minimum value for the cloud density
determined from the weather texture, to provide and easier-to-access method to
quickly change the overall density profile of the clouds.

As discussed in the [Raymarching](../Raymarching/Raymarching.md) page, we fade
out clouds by the horizon. When clouds are far away (therefore closer to the
horizon), the visual effect can be very busy, and since potential raymarching
distances are longer in those directions, performance can be effected.
Therefore, we also fade out clouds based on horizontal distance _from the
origin_. We calculate a fade fraction between two far-away distances, and
then take also `min(coverage, 1 - distanceFraction)` after performing
[height coverage](#height-coverage) modifications.

This ensures that cloud coverage (and hence density) will uniformly go to zero
once the further fade distance is reached.

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

Another visual effect we apply is to multiply the density by the coverage,
which makes edges of the cloud wispier and tends to lighten them. Again, we
parametrize the strength of this effect so a target look can be easily achieved.

As discussed in
[Raymarching](../Raymarching/Raymarching.md), we will fade out the coverage at
far distances, so that the density will go to zero smoothly.

## Height

Clouds have significantly different density profiles over their height ranges,
which we will look to model in three ways.

The first two will parametrize the combined effect of height and cloud type
upon the cloud shape. The first will be a simple multiplier for the base density,
while the second will provide the erosion value for the detail density.
Both will stored as a channel in a lookup texture, where the horizontal
coordinate parametrizes the cloud type, and the vertical coordinate parametrizes
the height fraction of the point in question.

The third will uniformly affect the cloud coverage based on height, to achieve an
anvil shape.

### Height Density

The density fraction will simply multiply the [base density](#base-density)
we unpack from the noise textures.

### Height Erosion

The erosion value is applied to the effect of the detail noise textures upon
the base density (with coverage applied). After we unpack the
[detail noise value](#detail-density), which lies in the range [0,1], we mirror
it depending on the erosion factor:
`lerp(1 - worleyDetail, worleyDetail, erosion)`. When we perform this mirroring
(low `erosion` values), the result tends to be wispier, which better lines up
with the shape of the bottom of the clouds. This guideline comes from discussion
of the
[Nubis system](https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine).

### Density-Erosion Lookup Texture

We'll use a fairly small 2D lookup texture with the density multiplier in the R
channel and the erosion value in the G channel. Again, we'll generate this by
hand in photo-editing software, following some guidelines from the
[Nubis system](https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine),
particularly regarding height distributions.

With increasing cloud type, we'll paint from lower-lying, flat clouds
(approximately stratus) to ones covering the full height of the atmosphere
(approximately cumulonimbus). Erosion will generally be larger at
higher altitudes, and not seen at all for the lower-lying clouds.

### Anvil Bias

Some https://en.wikipedia.org/wiki/Cumulonimbus_incus[types] of clouds have a
characteristic anvil shape, where the density starts to taper out from the top
of the cloud. We will model this by changing the coverage value based on a
given point's height fraction within the atmosphere.

By taking the coverage to some power less than 1, we can increase the coverage
for large height fractions. To find this exponent, we'll again use `Remap`:
`Remap(heightFraction, 0.7, 1.0, 1, 1 - AnvilBias)`. So at height fraction 0.7,
the power is 1, while at 1.0, the power is between 1 and 0, depending on the anvil
bias.

Note that large anvil bias values (very small powers) can cause the discretized
nature of weather texture coverage values to become obvious. Note that these
values will increment in steps of 1/255, due to 8-bit resolution of
each channel. Taking a small power when these values are small, these steps
can become noticeable.

## Final Density

We review the density calculation steps below.

* Base Density
    * Read cloud coverage, wetness and type from sampling Weather texture at current position
    * Scale and remap coverage based on global scale and minimum
    * Apply anvil shape bias by taking coverage to a height-based power
    * Reduce coverage to zero over large distances
    * Sample density multiplier and erosion values from cloud type and height
    * Get animated sample position from wind offset and height-based skew
    * Sample base noise texture and unpack
        * Perlin-Worley Noise in R channel, Worley fractal noise in GBA channels
        * Remap Perlin-Worley noise with minimum from Worley-fractal to 0
    * Multiply density by density-erosion multiplier
    * Apply coverage to density
        * Also reduce density by coverage to make cloud edges lighter
* Detail Density
    * Get curl animated sample position from additional wind offset
    * Sample and decode curl noise values
    * Apply curl noise value offset to base density's animated sample position
    * Sample and unpack Worley fractal noise
    * Interpolate between `1-detail` and `detail` based on erosion amount
    * Apply detail strength multiplier and detail maximum
    * Remap base density minimum range from detail amount to 0
* Final density
    * Multiply density by overall density scale
