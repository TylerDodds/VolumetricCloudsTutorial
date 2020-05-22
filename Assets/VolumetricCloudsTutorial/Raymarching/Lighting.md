# Lighting

## Overview

As discussed in [Raymarching](Raymarching.md),
we are concerned with how much light will make its way from the sun,
through the current raymarch point, and towards the direction of the camera.
Focusing on the single-scattering case, this involves determining the
_self-shadowing_ (transmission of light directly from the sun through the
clouds to the raymarch point), as well as the scattering _phase function_
that gives the probability of the light being scattered in a given direction.

This means that the fraction of the light intensity being scattered is given by
`transmittance * phase`, where `transmittance` is the transmittance from the
sun to the current point, and `phase` is the phase function evaluating the
fraction of scattering from that point in the direction of the camera.

In addition, we will also discuss techniques to approximate visual results of
multiple scattering events using our single-scattering machinery.
We also discuss a parametrized approximation for ambient lighting.
Finally, we determine how to take the raymarch results, and apply sun and ambient
light color and intensity to determine the final cloud color.

## Phase Function

A [phase function](http://glossary.ametsoc.org/wiki/Phase_function)
describes the fraction of scattered light in a given direction relative to
the incoming light. In most cases we consider, this will be _isotropic_; that is,
only the angle between incoming and outcoming light matters, not the orientation
of the outgoing direction in terms of left/right/up/down relative to the incoming
direction.

The phase function should be normalized, so the integral of the outgoing direction
over the entire sphere of angles equals one. This way, the total intensity of
incoming light is preserved over all outgoing scattering directions.

The actual phase function depends on the type of cloud, and can be quite complex.
Comparing to measurements and
[modelling an approximation](http://www-evasion.imag.fr/Publications/2006/BNL06/)
to the phase function is a challenging bit of work in its own right.
While we could encode these values in a look-up texture, like we did for some
aspects of the [Cloud Density](../CloudDensity/CloudDensity.md), we wish to be
conscious of performance, and may be able to parametrize a phase function that
achieves qualitatively reasonable results.

The Henyey-Greenstein (HG) [phase function](https://omlc.org/classroom/ece532/class3/hg.html),
originally used to describe single scattering from interstellar dust clouds,
can be used to approximate single scattering in other cases. It is parametrized
by an _eccentricity_ factor g:
p<sub>g</sub>(&theta;) = 1/(4&pi;) * (1 - g<sup>2</sup>)/(1 + g^<sup>2</sup> - 2gcos(&theta;))<sup>3/2</sup>.

Often, two instances of the HG function can be combined to approximate the important
parts of the cloud phase function. This will almost always include one instance
_g<sub>+</sub>_ with a high eccentricity (close to 1) contributing a narrow forward highlight,
and another one _g<sub>-</sub>_ with an eccentricity closer to zero (perhaps negative)
contributing more isotropic scattering.

We could average these phase functions,
(p<sub>g<sub>+</sub></sub>(&theta;) + p<sub>g<sub>-</sub></sub>(&theta;))/2,
yielding a still-normalized phase function that has some aspects of both.
However, we instead take the maximum:
max(p<sub>g<sub>+</sub></sub>(&theta;), p<sub>g<sub>-</sub></sub>(&theta;)).
Although the result is not normalized, it will yield more pronounced highlights.
Our [multiple-scattering approximation](#multiple-scattering-approximation) will also
alter the single scattering approximation in a non-normalized manner. In both
cases, we rely not on physical correctness, but on achieving the desired look.

## Self Shadowing

### Transmittance from Sun

We need to determine the fraction of light that reaches the current raymarch
point from the sun. This is precisely the Transmittance we discussed in
[Raymarching](Raymarching.md), although calculated from the raymarch point
in the direction of the sun.

However, we cannot afford to do an entirely new raymarch loop for each
point in our original raymarching! We will instead approximate the transmittance
exp(-&int;<sub>0</sub><sup>D</sup>&sigma;(z)dz) =
exp(-&sigma;<sub>S</sub>&int;<sub>0</sub><sup>D</sup>&rho;(z)dz)
by approximating the density integral &int;<sub>0</sub><sup>D</sup>&rho;(z)dz.

Like any other integral approximation, we'll sample the density, &rho;$, at
various positions, and weight each according to the step size. Keeping in mind
the performance constraint we just discussed, we'll keep the number of samples
very low, around 5.

Thanks to the exponential function in the transmittance, when the optical
distance is small, small changes will have a bigger effect on decreasing the
transmittance.
As a result, we'll increase the step size the further away we get from the
raymarch point. This way, we increase accuracy of our sampling for points close
to the edge of the cloud. We'll also increase the mipmap level used for
accessing the density noise texture along with the step size. This has two
benefits. One, the higher mipmap level will average out the noise texture,
meaning our sample will better represent the integral over its step size. Two,
this average happens in 3D texture space, so we are better able to incorporate
density information from further out in a cone-like manner. This way, we can
roughly approximate incorporating incoming light not only directly from the sun,
but from other angles through multiple scattering.

At each concurrent step, we will take a step of 1, 1, 2, 4, and 8 times the
base step size for the shadowing optical distance calculation.

### Transmittance Lightening

Since the transmittance from the sun only models a light coming directly from
the sun, and ignores multiple-scattering paths, values will be smaller than expected.

The base transmittance T<sub>B</sub> = exp(-&int;<sub>0</sub><sup>D</sup>&sigma;(z)dz)
= exp(-OD), where OD is known as the _optical depth_.
One way is to significantly reduce the optical depth, while also reducing the
overall transmittance:
T<sub>L</sub> = &alpha; exp(-&beta; OD), where &alpha;, &beta; &in; (0, 1].
We take &alpha; = 0.7, &beta; = 0.25.

Additionally, we reduce the lightened transmittance when the raymarch and sun
directions are close, and we expect strong forward scattering from the phase
function.
It is reduced by a factor `Remap(cosTheta, 0.7, 1.0, 1.0, 0.25)`, clamped to [0,1].

Finally, we take the maximum of the lightened and base transmissions, since the
goal is to prevent our single-scattering approximation from giving transmittance
values that look too dark.

## Multiple Scattering Approximation

One simple approximation that can be used to achieved some of the look of
multiple scattering is [discussed by Wrennige](http://magnuswrenninge.com/publications/attachment/wrenninge-ozthegreatandvolumetric),
and is suitable for use in our real-time system.

The idea is to sum over multiple 'octaves' of the base
transmittance-and-phase contribution. In each octave _i_ in `0 ... n-1`,
the extinction is lowered by some amount _a_<sup>_i_</sup>, to increase the
amount of light from the sun reaching the raymarch point. The eccentricity
used in the phase factor is also lowered by _b_<sup>_i_</sup>, and the
total light contribution is reduced by _c_<sup>_i_</sup>.
Three octaves (`i = 0, 1, 2`), and values of 0.5 each for _a_, _b_ and _c_ are
good starting points.

Then the light intensity fraction is approximated as:
&Sum;<sub>i</sub> _c_<sup>_i_</sup> p(&theta;, _g_ _b_<sup>_i_</sup>)
exp(- _a_<sup>_i_</sup> &int;<sub>0</sub><sup>D</sup>&sigma;(z)dz),
where _g_ is the eccentricity, p is the phase function, and the integral runs
along the direction from raymarch point to the sun, covering the distance needed
until it has exited the clouds.

We can rewrite
exp(- _a_<sup>_i_</sup> &int;<sub>0</sub><sup>D</sup>&sigma;(z)dz)
as exp(-&int;<sub>0</sub><sup>D</sup>&sigma;(z)dz)<sup>_a_<sup>_i_</sup></sup>
due to the exponent power rule. Then if exp(-&int;<sub>0</sub><sup>D</sup>&sigma;(z)dz)
= T<sub>S</sub> is the base transmittance between sun and raymarch point, we have
the final contribution:
&Sum;<sub>i</sub> _c_<sup>_i_</sup>
p(&theta;, _g_ _b_<sup>_i_</sup>)T<sub>S</sub><sup>_a_<sup>_i_</sup></sup>.

We will use a loop with the `[unroll]` attribute to perform all octave
calculations without branching. Using this, we may also easily alter the
number of octaves.

## Other Scattering Multipliers

Although we've used an approximation to simulate some of the extra intensity
from other in-scattering events, we've done so in an entirely local manner.
We can consider other _scattering probabilities_ based on where the raymarch
point is in the cloud.

First, we consider a height-based probability. Since there is no cloud material
underneath the clouds, there will be less chance for light to in-scatter at the
very bottom of the cloud layer. We transition from a minimum height-scattering
probability to 1 between a height range at the bottom of the clouds:
`pow(RemapClamped(HeightFraction, LowHeight, HighHeight, MinProbability, 1.0), Power)`.

Second, we consider a depth-based probability. Using a similar logic, we expect
points at the edges of clouds to have less surrounding material that can help
contribute to scattering. We can consider various methods to determine the
amount of density in the neighbourhood of a given point, which we can take as a
multiplier for the scattering probability. Taking the base density is a start,
and should not vary too quickly with raymarch position; as discussed in
[self-shadowing](#self-shadowing), we could even consider doing so at a higher
MIP level. By taking this to a height-dependent power (lower power at lower height),
we have a basic approximation for depth scattering.

Note that we could also use _transmittance_ as an approximation to this type
of depth scattering: the lower the transmittance, the further inside the cloud you
are. We will use the sun-to-raymarch point density integral as an additional factor;
when this is large, you are likely to be at a point significantly inside the
cloud (compared to the sun), so we expect the depth scattering probability to be
its maximum value of 1.

For more information, see the presentations on the
[Nubis system](https://www.guerrilla-games.com/read/nubis-authoring-real-time-volumetric-cloudscapes-with-the-decima-engine).
Note that the depth scattering approximation used to be described a 'Beer-powder law',
and used instead the transmittance towards the camera as an estimate for the
depth scattering probability.

## Ambient Lighting

In our implementation of a [multiple scattering approximation](#multiple-scattering-approximation),
we added several differently-parameterized single-scattering lighting.
We can also approach multiple-scattering approximations from the other end of the
directionality spectrum; namely, non-directional ambient light.
In this approach, we take a simple approximation to the final form of the light
that will have been a result of many scattering events through the clouds,
atmosphere, and the earth's surface.
In this way, we can add some of the illumination that would otherwise be missing
in our single-scattering approach, even with a multiple-scattering approximation.

### Single-Color Ambient

The simplest case is to assume that this ambient light is not only
independent of direction, but also independent of position. This can be
parametrized by just a single color.
We treat this as an additional source of light that comes from all directions,
and gets scattered back in the direction of the camera.
Therefore, we really need to take the integral overall _incoming_ ambient light
directions, with a uniform phase factor, to determine the intensity of ambient
light being included in our raymarch. This will exactly cancel out the phase
factor, leading to the full intensity of the ambient light being scattered in
the direction of the camera. Namely, S(a) = 1, as a fraction of the ambient
light intensity, which be included in the scattering
integral in the [raymarching](Raymarching.md).

### Ambient Scattering Rate

Although the main raymarch handles the scattering rate due to the current
position's density, we have also consider other
[scattering rate multipliers](#other-scattering-multipliers) for the lighting
that were meant to consider the effect of scattering in the neighbourhood around
that position. Since these effects are implicitly trying to model the type of
behavior due to multiple scattering events, we may also include them in
determining the scattering of ambient light.

### Top and Bottom Ambient

Like many other density parameters, we could also parametrize the ambient color
by height. By choosing a different color for the bottom and the top of the
clouds, we can capture colors of reflections from the earth (bottom) and the
color of the sky (top). We'll track the top and bottom intensities separately
in the raymarching, and compute the final color at [the end](#final-lighting).

We can take a slightly different approach
inspired by that of Patapom (see the accompanying
[real-time volumetric rendering course notes](https://patapom.com/topics/Revision2013/)).
The idea is to treat the top ambient lighting as coming uniformly from a slab at
the top of the atmosphere, and to treat the _amount_ of light reaching the
raymarch point as though the clouds were slab of uniform density and extinction
factor (and the same for a slab at the bottom).
The result for the bottom ambient terms ends up being the following:
exp(-heightScattering) + heightScattering * EI(-heightScattering),
where EI is the [exponential integral](https://en.wikipedia.org/wiki/Exponential_integral)
and heightScattering = &sigma;<sub>extinction</sub> * distanceFromBottom.

However, except for very small extinction factors, this tends to yield noticeable
ambient light contribution only on the bottom of the clouds.
The height-based density per cloud type, as discussed in
[Cloud Density](../CloudDensity/CloudDensity.md), will tend to not stretch the
full extent of the atmosphere's height.

However, looking at the _shape_ of the falloff, we see a function that
decreases with a nonlinear falloff, but less quickly than an exponential would.
We'll ignore the implicit distance scale in the height distance and the
extinction parameter, and instead take heightScattering to simply be the
height fraction.

We can also shape the height-intensity profile further. We'll multiply the top
intensity by `saturate(heightFraction * 2)` to reduce the effect of the top
color on the bottom of the clouds.

Finally, we can consider an even simpler, but more approximate, method of
handling the ambient color changing with height. We track only the total ambient
scattering intensity in the raymarch. Then, by using the raymarch's average
depth value, we can reconstruct the corresponding average position along the ray
that depth from the starting point. Using that average point's height, we can
combine the top and bottom ambient colors in any way -- linearly, with some
falloff (like discussed above), or perhaps even using a gradient of colors.
However, we will instead use the top-and-bottom-intensity raymarching discussed
above, preferring the look of the final output.

## Final Lighting

### Color

After the raymarching has been performed, we have the final transmittance from
the end point of the raymarch to the camera, as well as integrated intensity
_fractions_ for the sun (directional), ambient top, and ambient bottom light
sources.

Since `1 - Transmittance` is the opacity, this becomes the alpha channel value
for the cloud color. By multiplying the three intensity fractions by the three
associated light colors, we get the RGB portion of the color. Note that since our
raymarching already took transmittance into account, the final RGBA color value
is using [_premultiplied alpha_](https://en.wikipedia.org/wiki/Alpha_compositing#Straight_versus_premultiplied).

Why do we accumulate three intensity fraction values in the raymarching, instead
of the RGB light intensity values directly? One, we can save a few
multiplications at each step, but this effect is negligible. Two, it affords us
additional flexibility in how we encode these intensity fractions. This is
important when we try to use the previous frame's raymarch result to improve
the final look -- we will save the intensity fractions from frame to frame, and
have full control how those values are encoded and stored.

### Atmospheric Scattering

Throughout our raymarching, density, and scattering calculations,
we've considered scattering coming from the clouds themselves.
What is outside of scope for this project is
[Atmospheric Scattering](https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-16-accurate-atmospheric-scattering), the scattering of light caused by the rest of the
atmosphere.

Light will be scattered by the atmosphere before it reaches the clouds, and
also between the clouds and the camera. Furthermore, the presence of clouds
will affect the usual calculations for atmospheric scattering, which will likely
assume an atmospheric density that falls off only with height.

Atmospheric scattering is an important consideration to generate visually
consistent results of rendering the whole sky and other far-away elements.

## Color Space

All of our discussions on light transmittance and scattering implicitly assumes
that our colors are physical quantities of light. Therefore, we must use a
__Linear__ color space space, instead of a __Gamma__ one (see
[this discussion](https://docs.unity3d.com/Manual/LinearRendering-LinearOrGammaWorkflow.html)
for details).
There are likely no cases where a platform can support a full volumetric clouds
rendering solution, but not a full Linear color space.

Nonetheless, we can take some steps to ensure that we obtain consistent results
even if the project happens to be in Gamma space. Since our raymarching implicitly
happens using linear (physical) lighting, we simply convert all appropriate
quantities to that format for the raymarching and blending, and convert back
to Gamma space afterwards:

* Ensure that the sun color is converted from Gamma to Linear space.
* Ensure that the scene color is converted from Gamma to Linear space
before blending.
* Ensure that the final color is converted from Linear to Gamma space
after blending.

Using the `GammaToLinearSpace` and similar functions in `UnityCG.cginc`
can help us in the conversion.
