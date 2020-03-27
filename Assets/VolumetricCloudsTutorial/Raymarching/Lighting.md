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
Our [multi-scattering approximation](#multi-scattering-approximation) will also
alter the single scattering approximation in a non-normalized manner. In both
cases, we rely not on physical correctness, but on achieving the desired look.

## Self-Shadowing

We need to determine the fraction of light that reaches the current raymarch
point from the sun. This is precisely the Transmittance we discussed in
[Raymarching](Raymarching.md), although calculated from the raymarch point
in the direction of the sun.

However, we cannot afford to do an entirely new raymarch loop for each
point in our original raymarching! We will instead approximate the transmittance
exp(-&int;<sub>0</sub><sup>D</sup>&sigma;(z)dz) =
exp(-&sigma;<sub>S</sub>&int;<sub>0</sub><sup>D</sup>&rho;(z)dz)
by approximating the _optical distance_ &int;<sub>0</sub><sup>D</sup>&rho;(z)dz.

Like any other integral approximation, we'll sample the density, &rho;$, at
various positions, and weight each according to the step size. Keeping in mind
the performance constraint we just discussed, we'll keep the number of samples
very low, around 5. We'll only

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

## Multi-Scattering Approximation

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

Note that we can rewrite
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

TODO

## Ambient Lighting

TODO

## Final Lighting

TODO
