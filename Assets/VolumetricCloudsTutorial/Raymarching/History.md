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

## Setup

We will set up an ImageEffect in `CloudHistoryEffect.cs` containing multiple
passes that will perform raymarching for the current frame, combine it with a
historical result, then apply lighting and blend with the scene. Each of these
steps will be a separate pass in the shader, `CloudHistoryEffectShader.shader`.

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

### Render Target Setup

We note that the output of our raymarching contains _five_ values that we will
need to write to RenderTextures in Pass 0. Four of these will be used in
determining the final color, including transmittance and three light intensity
fractions: directional, ambient (top), and ambient (bottom).
The average depth is not used in determining the color, so will only be used in
the input of Pass 1, not its output into one of the history buffers.
Therefore, `RenderTextureFormat.ARGBFloat` can be used to pack the transmittance
and intensity values into one RenderTexture, and `RenderTextureFormat.RFloat`
for the average depth.

We can use the `Graphics.SetRenderTarget` function, specifying a
`RenderTargetSetup` with the two color `RenderBuffer` of the `RenderTexture`s
above. `BlitMRT` in `ImageEffectBase` handles setting up the render targets
and material pass, then drawing the full-screen quadrilateral.

### History Double Buffers

We will have two buffers to store the result of blending with history,
each with the same `RenderTextureFormat.ARGBFloat` format as the raymarch
transmittance and intensity results from Pass 0.
Each frame, in Pass 1's `Graphics.Blit` command, we will use one of these as the
source RenderTexture, and the other as the destination RenderTexture.
We switch their roles every other frame, so that the output of one frame becomes
the historical input for the next frame.

### Vertex Shader

The incoming vertex data requires only position and uv input data:
`float4 vertex : POSITION` and `float2 uv : TEXCOORD0`.
The vertex shader will forward those two values to the fragment shader, as
well as the screen position, `float4 screenPos : TEXCOORD1` using UnityCG's
`ComputeScreenPos`, and the view-space ray xy coordinates at z-distance of 1,
`float2 viewRay : TEXCOORD2`, computed using the results of
GetProjectionExtents decribed in [ImageEffects](../ImageEffects/ImageEffects.md).

Pass 0 does not need the uv values, so they are not forwarded to its fragment
shader.

### Downscaling

We set up two buffers to hold the results of Pass 0, and two history buffers
to hold the input and ouput of Pass 1. In the highest-quality scenario, we will
create these all with the height and width of the screen, so that each pixel
of the final image will map in a 1-to-1 fashion to a pixel from the current
history buffer. In turn, the blending in Pass 1 will map 1-to-1 to the raymarch
results in Pass 0.

However, we may instead downscale _all_ of these textures to half or quarter
size, significantly reducing the number of pixels we need to perform raymarching
on in Pass 0, and also reducing the number of pixels used for blending in Pass 1.
The final pass will write to the screen, looking up from the lower-resolution
history buffer using bilinear interpolation.

In practice, at larger screen resolutions and  for many sets of cloud
configuration parameters, using half-resolution buffers is not noticeably
visually different from full-resolution ones, and saves a significant amount
of execution time.

## Passes

### 0: Raymarch (Moderate Quality)

First, we calculate the xy screen-space coordinates from the 4D projective
coordinates returned by the vertex shader, which becomes the uv value for
the scene depth texture lookup. We also multiply a point on the view-space ray by
unity_CameraToWorld so we can calculate the world-space direction of the
raymarch.

Next, we compute the raymarch offset. We already discussed varying the offset
uniformly with time in a low-discrepancy manner. We will also wish to do so
spatially, as well. We will offset the radius by a Bayer matrix applied over
groups of 3x3 pixels, using concepts from
[ordered dithering](https://en.wikipedia.org/wiki/Ordered_dithering).
This is needed because we will add a step in Pass 1 that will look up
raymarch values in a 3x3 neighbourhood, and we want to make sure we have a full
distribution of offset fractions over that region, so all samples are not just
from the same depth along the raymarch. Otherwise, neighbouring pixel results
would be independent, and we could rely on the historical blending and uniform
raymarch offset to handle proper depth sampling. By dividing the screen position
by the texel size, we obtain a 2D pixel ID, which is used to determine the index
within the repeating 3x3 Bayer matrix. This offset is added to the uniform
raymarch offset, and brought back into the [0, 1] range.

Finally, we perform raymarching, returning the average depth value as a `float`,
and the transmittance and intensity values as a `float4`, to the two targets
of this pass. Note that we also handle here cases where there will be no
raymarching, (an object in the way, or when the ray does not pass through the atmosphere)
as well as the horizon angle fading discussed in [Raymarching](Raymarching.md).

### 1: Blend Raymarch into History

#### Previous View Lookup

We begin by looking up the two results from the previous pass using the
screen-space uv values, and re-calculate the world-space raymarch direction.
Then, using the average depth raymarch result, we calculate the corresponding
3D world-space position as the representative point along the ray.

Taking this world position
to homogeneous coordinates, multiplying by the previous frame's view-projection
matrix, taking the x-y non-homogeneous coordinates by dividing by w, we get the
uv-space position of that point with respect to the previous frame's camera
matrix. We use
`GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * camera.worldToCameraMatrix)`
to assign the view-projection matrix to the material in the correct format.

With this uv, we can simply sample from the history buffer to look up the
raymarch transmittance and intensity values from the previous frame along a
roughly equivalent ray. Note that if the camera is only rotating, all rays from
both frames will start at the same position, so this lookup is exact; different
points along the current frame's ray will lie on the same ray with respect to the
previous frame's camera. If the camera is moving, however, lookup up the
previous frame's values from this approximate center of density is needed to
ensure that the lookup is yielding correspondingly similar transmittance and
intensity values.

#### Blending

The final step is to combine the previous frame's final result from the history
buffer, with the current frame's Pass 0 raymarch results, producing the final
sample for this frame that will be stored into the new history buffer.

Let's first consider the case when the ray lookup uv was found within the
[0,1]x[0,1] uv space of the history buffer. In this case, we perform a
frame-by-frame interpolation:
`lerp(history, raymarch, fraction)`, where we choose a small fraction around 0.05.
Let's consider how this interpolation will look like with a sudden change in the
base raymarch value, going from 1 (in the history buffer) to zero
(in subsequent raymarch passes). At time t, in increments of &Delta;t per frame
(around 1/60 of a second),
R(t + &Delta;t) = R(t)(1-f) + 0*f, where R(0) = 1. So
[R(t + &Delta;t) - R(t)]/&Delta;t = -fR(t)/&Delta;t.
This is a simple differential equation: dR(t)/dt = -(f/&Delta;t)R(t), and the solution is
an exponential: R(t) = A exp(-(f/&Delta;t) t), where in this case the constant A = 1 so
that R(0) = 1, the initial value.
In short, this means that new values will be blended to exponentially, with a
half-life of T<sub>H</sub> = ln(2) &Delta;t / f, around 0.23 s for the values
discussed above. Alternatively, f = ln(2) &Delta;t / T<sub>H</sub>, and we
can parametrize T<sub>H</sub> directly.

Now we consider when the ray lookup uv was found outside of [0,1]x[0,1]. We
consider the maximum distance outside of the unit square along either x or y axis.
If this value is larger than the blend fraction, we use it instead. In this way,
we can weigh newly-uncovered pixels at the edges of the screen much more heavily
with the current raymarch results, while still blending with the results of the
history buffer. By using `TextureWrapMode.Clamp`, this lookup can at best
clamp to the edge of the texture, but we can expect some amount of spatial
coherence. In practice, this works well enough to handle camera rotation.

#### Neighbourhood Lookup

While lookup and blending alone may be enough to handle camera rotation, the
case of camera translation may still end up with significantly different
values between the previous frame's lookup and the current raymarch values.
However, these will still be blended with the usual weight, and in these cases
the half-life discussed above will be noticeable. This effect is most obvious
at the edges of clouds.

Just like we did for the case where the previous uv fell outside of the screen,
we wish to weight values towards the current raymarch values more highly in
these cases. To help determine if the previous and current raymarch values are
significantly different, we'll also consider the values in the 3x3 neighbourhood
of pixels of the current frame. If there is little spatial variance, but a
significant difference from last frame, we'll want to trust the current frame's
values more.

From the values in this 3x3 area, we will determine the average and standard
deviation for each of the four raymarch values: the transmittance and three
intensities. We create a four-dimensional bounding box centered at the average
of these values, with a width of 1.5 times the standard deviation. This box
encapsulates roughly the expected spatial range of the values in the
neighbourhood. Note that this 3x3  size is the same as our repeating
Bayer matrix for the raymarch offset, so we can be sure that the depth is sampled
appropriately within each neighbourhood.

Before performing blending, we clamp the previous frame's looked-up value to the
closest point on the bounding box, if it lies outside. This will make the
blending look more temporally consistent when the camera performs translations.

### 2: Apply Lighting, Blend with Scene

In this pass, we look up the scene color and recent history buffer's
transmittance and intensity values. We then look up the raymarch color
from these intensity values, and blend with the scene color based on the
transmittance. Note that we also perform this blending in linear space,
meaning we need to convert from and to Gamma space if that's the color space
our project is using.
