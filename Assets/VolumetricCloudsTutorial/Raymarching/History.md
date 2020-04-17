# History

## Overview

Performing raymarching each frame is expensive. Instead of adding additional
steps to each frame, we can instead try to use previous frames' results to
supplement the current frame's results.

TODO - discuss Nubis-style high-quality raymarching one pixel per frame per group

TODO

## Setup

We will set up an ImageEffect in `CloudHistoryEffect.cs` containing multiple
passes that will perform raymarching for the current frame, combine it with a
historical result, then apply lighting and blend with the scene. Each of these
steps will be a separate pass in the shader.

* Pass 0: Raymarch intensities and average depth. We'll need to save these in a
RenderTexture to be used in the next pass.
* Pass 1: Combine current raymarch with previous history. Using the previous
frame's camera view matrix, we look up from the past frame's history, combine it
with pass 0's result, and write it to this frame's history. We need a
double-buffer to store previous and current frame's history, and we switch between
them every frame.
* Pass 2: Combine the current frame's combined history result with the scene,
applying raymarch lighting using pre-multiplied alpha blending
(see [Lighting](Lighting.md)).

### Raymarch Offset

Of course, if the camera doesn't change frame-to-frame, with reasonable values
of wind speed, pass 0 will simply be performing the same raymarch calculation
frame-to-frame. That is, the raymarch steps will land at the same places, and
our results suffer the safe effects from the corresponding approximation.

Particularly at the edge of the cloud closest to the camera, small raymarch
steps are crucial to correctly sampling the cloud density with enough detail.
Since transmittance there is still large, the closest edges of the clouds will
contribute the most to the total scattering intensity.

By uniformly offsetting the raymarch start position by a different fraction of
the step size each frame, we can ensure that, over time, we evaluate raymarching
at a much finer level of detail over each step. This way, we can average over
raymarch contributions along each step by combining previous intensity values
with the current ones.

TODO - discuss low discrepancy sequence
TODO - discuss non-equal steps

## Passes

### Raymarch (Low Quality)

TODO

### Blend Raymarch into History

TODO

### Apply Lighting, Blend with Scene

TODO
