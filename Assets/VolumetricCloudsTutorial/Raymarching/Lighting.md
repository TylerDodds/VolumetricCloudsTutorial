# Lighting

## Overview

As discussed in [Raymarching](Raymarching.md),
we are concerned with how much light will make its way from the sun,
through the current raymarch point, and towards the direction of the camera.
Focusing on the single-scattering case, this involves determining the
_self-shadowing_ (transmission of light directly from the sun through the
clouds to the raymarch point), as well as the scattering _phase function_
that gives the probability of the light being scattered in a given direction

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

## Multi-Scattering Approximation

TODO

## Self-Shadowing

TODO

## Ambient Lighting

TODO

## Final Lighting

TODO
