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

TODO

## Multi-Scattering Approximation

TODO

## Self-Shadowing

TODO

## Ambient Lighting

TODO

## Final Lighting

TODO
