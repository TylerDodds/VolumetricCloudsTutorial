# Image Effects

## Base Image Effect (`ImageEffectBase.cs`)

### Overview

We use Unity's [OnRenderImage](https://docs.unity3d.com/ScriptReference/MonoBehaviour.OnRenderImage.html)
MonoBehaviour Message to perform shader-based post-processing of the rendered image.

Using the `[ImageEffectOpaque]` attribute, we ensure that our post-processing step
happens after all opaque objects have been rendered. In particular, this allows
us to use the [depth buffer's](https://docs.unity3d.com/Manual/SL-DepthTextures.html)
information to ensure that we do not draw clouds when they are behind opaque objects
in the scene.

Afterwards, since transparent objects will be drawn without updating depth
information, we must constrain our use to cases where transparent objects will
occur only in front of clouds.

### RenderTexture

A Unity
[RenderTexture](https://docs.unity3d.com/ScriptReference/RenderTexture.html) is
a texture that can be rendered to. `OnRenderImage` takes a RenderTexture as both
input ("source") and output ("destination").

Using `[ImageEffectOpaque]`, Unity will provide the input RenderTexture with
the skybox and all opaque objects drawn. It's up to us to draw that same scene
-- with clouds added -- into the output RenderTexture.

Since we're not using a
[Scriptable Render Pipeline](https://docs.unity3d.com/Manual/ScriptableRenderPipeline.html),
there are a few options we have to perform rendering from the input to the output
RenderTexture. We could use a
[Command Buffer](https://docs.unity3d.com/Manual/GraphicsCommandBuffers.html)
to extend Unity's default rendering pipeline, the
[Graphics](https://docs.unity3d.com/ScriptReference/Graphics.html) class to
use Unity's mesh rendering, or the
[GL](https://docs.unity3d.com/ScriptReference/GL.html) class for immediate-mode
type rendering.

For image effects, historically one of two approaches is used.
1. [`Graphics.Blit`](https://docs.unity3d.com/ScriptReference/Graphics.Blit.html)
function copies a source Texture to a destination RenderTexture, applying a
given material.
2. [`Gl.Begin`](https://docs.unity3d.com/ScriptReference/GL.Begin.html) function
can directly draw primitives with the currently-assigned material. We draw a
full-screen quadrilateral to the output RenderTexture.

`Graphics.Blit` is generally more straightforward, and handles
[platform-specific rendering differences](https://docs.unity3d.com/Manual/SL-PlatformDifferences.html)
of RenderTexture coordinates. One result is that if you're processing many
RenderTextures at a time, some may be flipped vertically, depending on the platform.
Unity defines the shader preprocessor macro `UNITY_UV_STARTS_AT_TOP` in this case.
In many cases, we may wish to perform processing in multiple passes, or store the
result of an intermediate calculation in a RenderTexture for use when the next
frame is rendered. In these cases, `Graphics.Blit` is easy to use with
temporary RenderTextures that we create (not supplied by the source or
destination parameters).

However, using `GL.Begin`, we can set the normal vectors of the four vertices of
the quadrilateral to be the view vectors of the four corners of the frustum.
These will be interpolated in the shader, so we can easily reconstruct the view
ray from the camera at any point sampled.

### Class Overview

#### `EnsureRenderTexture(ref RenderTexture rt, int width, int height, RenderTextureFormat format, FilterMode filterMode, TextureWrapMode wrapMode = TextureWrapMode.Clamp, bool randomWrite = false, bool useMipmap = false, int depthBits = 0, int antiAliasing = 1)`

By passing the RenderTexture by reference, we can create a new RenderTexture with
the given parameters if they do not match, and assign it to the reference.

As mentioned, we will be creating temporary RenderTexture mostly for in-between
calculations, perhaps to be stored for use in the next frame for bootstrapping.
These RenderTextures will therefore be full-screen representations of some
intermediate step, though in many cases they may be downscaled to save on
computation time. We can choose to perform upscaling and downscaling in powers
of 2 for best quality
([downsampling](https://en.wikipedia.org/wiki/Downsampling_(signal_processing)
and other sampling issues are covered in depth in most treatments of
real-time rendering).

With this in mind, let's look at the parameters:

* Width: Width of the RenderTexture. Usually the width of the screen, or some
power of 2 smaller, as discussed above.
* Height: Height of the RenderTexture. See discussion for Width.
* RenderTextureFormat: the format of the RGBA channels of the texture. Usually
we will `RenderTextureFormat.ARGBFloat` so we can store floating-point precision
results of our calculation at each step.
* FilterMode: How to sample this texture, when sampling in-between neighbouring
pixels -- for instance, when a downscaled RenderTexture is sampled at the full
screen resolution. `FilterMode.Bilinear` is usually preferred.
* TextureWrapMode: How to sample when outside the edges of the texture.
`TextureWrapMode.Clamp` is usually preferred, since we are sampling in
screen space and do not wish to wrap to the other side. This is relevant if we
are performing calculations that take information from neighbouring pixels in
screen space and those might fall off the edge of the screen.
* RandomWrite: whether Shader Model 5 random write feature is enabled. We will
not be using this feature.
* UseMipmap: if a set of Mipmap images for this RenderTexture should be
generated. [Mipmaps](https://en.wikipedia.org/wiki/Mipmap) are lower-resolution
representation of images, and since we're working with screen-space calculations,
we only need the one resolution that we've chosen.
* DepthBits: the number of bits of the depth buffer for this RenderTexture.
We don't need an additional depth buffer, since we already have
[access](https://docs.unity3d.com/Manual/SL-DepthTextures.html) to the scene's
Depth information, so we leave this as 0.
* AntiAliasing: the number of samples per pixel. We leave this at 1, since we
again are only performing screen-space calculations, and bilinear sampling of
any downscaled intermediate results will be sufficient.

#### `Vector4 GetProjectionExtents(Camera camera, float texelOffsetX, float texelOffsetY)`

This function get the frustum extents and jitter at distance 1 from the camera.
The jitter is given in units of texels, specified by the two input `texelOffset`
parameters.

By passing these values into the shader, we can determine the location of a
sampled point at distance 1 in view (camera) space, which can be used to
reconstruct the view direction vector of the sample.

For some calculations, we may wish to add some jitter in x and y to the sampled
position, but we will concern ourselves with the case
`texelOffsetX = texelOffsetY = 0`.

#### `DrawFullScreenQuad(Camera camera, RenderTexture destination)`

As discussed above, uses `Gl.Begin` and related functions to drawn a full-screen
quadrilateral from two triangles, storing the frustum corner direction vectors
in the texture coordinate normals.

#### `[SerializeField] Shader _shader`
Shader for the image effect, to be serialized and set in the Inspector.

#### `Material _material`
The Material instantiated from `_shader`.

#### `Camera _camera`
The Camera component on this GameObject. We ensure one exists by adding the
`[RequireComponent(typeof(Camera))]` attribute to the class.

Obtained in Unit's Awake() message
function and ensured to have depth in OnEnable(), through
`_camera.depthTextureMode |= DepthTextureMode.Depth`.

#### `OnRenderImage(RenderTexture source, RenderTexture destination)`

If no Shader is set, we only call `Graphics.Blit(source, destination)` to
copy the source RenderTexture to the destination.

Otherwise, we ensure a Material is created with the chosen Shader,
and set the Material's `_MainTex` property as the source RenderTexture.
We then call our two abstract functions: `UpdateMaterial` and `PerformEffect`.
Respectively, these update the rest of the Material's properties, and perform
the full-screen effect (using the techniques described above).

## `CloudEffectBase.cs`

This MonoBehaviour inherits from `ImageEffectBase`, and holds a reference to
a `CloudConfiguration` instance, holding all of the visual parameters relevant
for cloud rendering.

It also serialized the raymarch quality (Low, Normal, or High),
determining the step size of the raymarching, as well as if adaptive raymarch
step size is being used (see [Raymarching](../Raymarching/Raymarching.md)).
