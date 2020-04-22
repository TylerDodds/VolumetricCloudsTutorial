# History

## Overview

Performing raymarching each frame is expensive. Instead of adding additional
steps to each frame, we can instead try to use previous frames' results to
supplement the current frame's results.

We can consider two main styles of approach. The first is to perform raymarching
at very small step size, but update only one pixel in a group of neighbours each
frame. This approach is taken by the Nubis system, evaluating one pixel in a
group of 4x4 each frame.

The second is to perform raymarching at a more moderate step size, but update
each pixel every frame, relying on the time average to ontain higher-quality
results than the step size alone could achieve. This is the approach taken by
Frostbite, as can be seen in yangrc1234's
[VolumeCloud GitHub repo](https://github.com/yangrc1234/VolumeCloud) --
particularly check out the corresponding notes on the
[implementation details](https://github.com/yangrc1234/VolumeCloud/blob/master/IMPLEMENTATIONDETAIL.md).
This is the approach we will also follow.

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

We'd like our offset to cover the range [0, 1] uniformly, and to continue to do
so as additional frame pass. A
[low-discrepancy sequence](https://en.wikipedia.org/wiki/Low-discrepancy_sequence)
perfectly fits the bill for this. We implement a simple one-dimensional
[Halton sequence](https://en.wikipedia.org/wiki/Halton_sequence) in
`LowDiscrepancySequence.cs`. Each time we perform the image effect, we get the
next value in the sequence as the raymarch offset.

This ties into the discussion of non-equal step sizes in
[Raymarching](Raymarching.md).

## Passes

### Raymarch (Low Quality)

TODO

### Blend Raymarch into History

TODO

### Apply Lighting, Blend with Scene

TODO
