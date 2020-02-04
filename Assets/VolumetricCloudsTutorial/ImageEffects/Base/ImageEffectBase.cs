using UnityEngine;

namespace VolumetricCloudsTutorial.ImageEffects.Base
{
    /// <summary>
    /// Base MonoBehaviour for performing image effects in Unity's OnRenderImage
    /// </summary>
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public abstract class ImageEffectBase : MonoBehaviour
    {
        /// <summary>
        /// If needed, creates and assigns a new RenderTexture by reference with the appropriate size and formats.
        /// </summary>
        /// <param name="rt">The RenderTexture</param>
        /// <param name="width">Width of the RenderTexture</param>
        /// <param name="height">Height of the RenderTexture</param>
        /// <param name="format"><see cref="RenderTextureFormat"/> of the RenderTexture</param>
        /// <param name="filterMode"><see cref="FilterMode"/>of the RenderTexture</param>
        /// <param name="wrapMode"><see cref="WrapMode"/> of the RenderTexture</param>
        /// <param name="randomWrite">If RandomWrite of the RenderTexture should be set</param>
        /// <param name="useMipmap">If MipsMaps of the RenderTexture should be used</param>
        /// <param name="depthBits">Number of depth bits of the RenderTexture</param>
        /// <param name="antiAliasing">Level of Antialiasing of the RenderTexture</param>
        /// <returns>If a new RenderTexture was created.</returns>
        protected static bool EnsureRenderTexture(ref RenderTexture rt, int width, int height, RenderTextureFormat format, FilterMode filterMode, TextureWrapMode wrapMode = TextureWrapMode.Clamp, bool randomWrite = false, bool useMipmap = false, int depthBits = 0, int antiAliasing = 1)
        {
            if (rt != null && (rt.width != width || rt.height != height || rt.format != format || rt.filterMode != filterMode || rt.enableRandomWrite != randomWrite || rt.wrapMode != wrapMode || rt.antiAliasing != antiAliasing || rt.useMipMap != useMipmap))
            {
                rt.Release();
                rt = null;
            }

            if (rt == null)
            {
                rt = new RenderTexture(width, height, depthBits, format, RenderTextureReadWrite.Default);
                rt.antiAliasing = antiAliasing;
                rt.useMipMap = useMipmap;
                rt.filterMode = filterMode;
                rt.enableRandomWrite = randomWrite;
                rt.wrapMode = wrapMode;
                rt.Create();
                return true;
            }

            return false;
        }

        /// <summary>
        /// Releases a RenderTexture by reference.
        /// </summary>
        /// <param name="rt">The RenderTexture</param>
        protected static void ReleaseRenderTexture(ref RenderTexture rt)
        {
            if (rt != null)
            {
                RenderTexture.ReleaseTemporary(rt);
                rt = null;
            }
        }

        /// <summary>
        /// Gets the projection extents at distance 1 for a specified Unity Camera and zero texel offset.
        /// </summary>
        /// <param name="camera">The Unity Camera.</param>
        /// <param name="texelOffsetX">The x texel offset for determining jitter.</param>
        /// <param name="texelOffsetY">The y texel offset for determining jitter.</param>
        /// <returns>Frustum extents and jitter at distance 1, in xy and zw coordinates respectively.</returns>
        protected static Vector4 GetProjectionExtents(Camera camera)
        {
            return GetProjectionExtents(camera, 0.0f, 0.0f);
        }

        /// <summary>
        /// Gets the projection extents at distance 1 for a specified Unity Camera and texel offsets.
        /// </summary>
        /// <param name="camera">The Unity Camera.</param>
        /// <param name="texelOffsetX">The x texel offset for determining jitter.</param>
        /// <param name="texelOffsetY">The y texel offset for determining jitter.</param>
        /// <returns>Frustum extents and jitter at distance 1, in xy and zw coordinates respectively.</returns>
        protected static Vector4 GetProjectionExtents(Camera camera, float texelOffsetX, float texelOffsetY)
        {
            if (camera == null)
                return Vector4.zero;

            float oneExtentY = camera.orthographic ? camera.orthographicSize : Mathf.Tan(0.5f * Mathf.Deg2Rad * camera.fieldOfView);
            float oneExtentX = oneExtentY * camera.aspect;
            float texelSizeX = oneExtentX / (0.5f * camera.pixelWidth);
            float texelSizeY = oneExtentY / (0.5f * camera.pixelHeight);
            float oneJitterX = texelSizeX * texelOffsetX;
            float oneJitterY = texelSizeY * texelOffsetY;

            return new Vector4(oneExtentX, oneExtentY, oneJitterX, oneJitterY);
        }

        /// <summary>
        /// Draws a full-screen quad to the destination RenderTexture using <see cref="GL"/> commands.
        /// </summary>
        /// <param name="camera">The Camera</param>
        /// <param name="destination">The desination RenderTxture</param>
        protected static void DrawFullScreenQuad(Camera camera, RenderTexture destination)
        {
            // Calculate vectors towards frustum corners.
            var camtr = camera.transform;
            var camNear = camera.nearClipPlane;
            var camFar = camera.farClipPlane;

            var tanHalfFov = Mathf.Tan(camera.fieldOfView * Mathf.Deg2Rad / 2);
            var toRight = camtr.right * camNear * tanHalfFov * camera.aspect;
            var toTop = camtr.up * camNear * tanHalfFov;

            var v_tl = camtr.forward * camNear - toRight + toTop;
            var v_tr = camtr.forward * camNear + toRight + toTop;
            var v_br = camtr.forward * camNear + toRight - toTop;
            var v_bl = camtr.forward * camNear - toRight - toTop;

            var v_s = v_tl.magnitude * camFar / camNear;

            // Draw screen quad.
            RenderTexture.active = destination;

            GL.PushMatrix();
            GL.LoadOrtho();
            GL.Begin(GL.QUADS);

            GL.MultiTexCoord2(0, 0, 0);
            GL.MultiTexCoord(1, v_bl.normalized * v_s);
            GL.Vertex3(0, 0, 0.1f);

            GL.MultiTexCoord2(0, 1, 0);
            GL.MultiTexCoord(1, v_br.normalized * v_s);
            GL.Vertex3(1, 0, 0.1f);

            GL.MultiTexCoord2(0, 1, 1);
            GL.MultiTexCoord(1, v_tr.normalized * v_s);
            GL.Vertex3(1, 1, 0.1f);

            GL.MultiTexCoord2(0, 0, 1);
            GL.MultiTexCoord(1, v_tl.normalized * v_s);
            GL.Vertex3(0, 1, 0.1f);

            GL.End();
            GL.PopMatrix();
        }

        protected virtual void Awake()
        {
            _camera = GetComponent<Camera>();
        }

        protected virtual void OnEnable()
        {
            _camera.depthTextureMode |= DepthTextureMode.Depth;
        }

        /// <summary>
        /// Abstract function to update the image effect's Material before rendering
        /// </summary>
        /// <param name="material">The Material to update</param>
        protected abstract void UpdateMaterial(Material material);

        /// <summary>
        /// Abstract function to perform the image effect during <see cref="OnRenderImage(RenderTexture, RenderTexture)"/>
        /// </summary>
        /// <param name="material">The material for the effect</param>
        /// <param name="camera">The Camera</param>
        /// <param name="source">The source RenderTexture</param>
        /// <param name="destination">The destination RenderTexture</param>
        protected abstract void PerformEffect(Material material, Camera camera, RenderTexture source, RenderTexture destination);

        /// <summary>
        /// Updates material and performs image effect.
        /// </summary>
        /// <param name="source">Source RenderTexture</param>
        /// <param name="destination">Destination RenderTexture</param>
        [ImageEffectOpaque]
        private void OnRenderImage(RenderTexture source, RenderTexture destination)
        {
            if (_shader == null)
            {
                Graphics.Blit(source, destination);
                return;
            }

            if (_material == null)
            {
                _material = new Material(_shader);
                _material.hideFlags = HideFlags.DontSave;
            }

            _material.SetTexture("_MainTex", source);
            UpdateMaterial(_material);

            PerformEffect(_material, _camera, source, destination);
        }

        /// <summary>
        /// Shader for the image effect, to be serialized and set in the Inspector
        /// </summary>
        [SerializeField] Shader _shader;

        /// <summary>
        /// The Material instantiated from <see cref="_shader"/>
        /// </summary>
        Material _material;

        /// <summary>
        /// The Camera component on this GameObject
        /// </summary>
        Camera _camera;
    }
}