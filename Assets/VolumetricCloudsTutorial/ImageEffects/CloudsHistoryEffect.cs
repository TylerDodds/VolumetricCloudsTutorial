using UnityEngine;
using VolumetricCloudsTutorial.Configuration;

namespace VolumetricCloudsTutorial.ImageEffects
{
    /// <summary>
    /// MonoBehaviour for performing clouds image effect in Unity's OnRenderImage
    /// </summary>
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    [AddComponentMenu("Volumetric Clouds/Clouds Raymarching and History")]
    public class CloudsHistoryEffect : Base.CloudEffectBase
    {
        /// <summary>
        /// The power of 2 used to downscale raymarching and history blending textures from the screen size. 
        /// </summary>
        [Tooltip("The power of 2 used to downscale raymarching and history blending textures from the screen size.")]
        [SerializeField] [Range(0, 2)] private int _downscaling = 0;

        /// <summary>
        /// The half-life used during the blending update.
        /// </summary>
        [Tooltip("The half-life used during the blending update.")]
        [SerializeField] [Range(0.01f, 1)] private float _blendHalfLife = 0.23f;

        /// <summary>
        /// Perform the image effect during <see cref="OnRenderImage(RenderTexture, RenderTexture)"/>
        /// </summary>
        /// <param name="material">The material for the effect</param>
        /// <param name="camera">The Camera</param>
        /// <param name="source">The source RenderTexture</param>
        /// <param name="destination">The destination RenderTexture</param>
        protected override void PerformEffect(Material material, Camera camera, RenderTexture source, RenderTexture destination)
        {
            int width = source.width >> _downscaling;
            int height = source.height >> _downscaling;

            if (_historyDoubleBuffers == null)
            {
                _historyDoubleBuffers = new RenderTexture[2];
            }
            _isFirstFrame |= EnsureRenderTexture(ref _historyDoubleBuffers[0], width, height, RenderTextureFormat.ARGBFloat, FilterMode.Bilinear);
            _isFirstFrame |= EnsureRenderTexture(ref _historyDoubleBuffers[1], width, height, RenderTextureFormat.ARGBFloat, FilterMode.Bilinear);
            _isFirstFrame |= EnsureRenderTexture(ref _raymarchedBuffer, width, height, RenderTextureFormat.ARGBFloat, FilterMode.Bilinear);
            _isFirstFrame |= EnsureRenderTexture(ref _raymarchAvgDepthBuffer, width, height, RenderTextureFormat.RFloat, FilterMode.Bilinear);
            if(_raymarchColorBuffers == null || _raymarchColorBuffers.Length != 2)
            {
                _raymarchColorBuffers = new RenderBuffer[] { _raymarchedBuffer.colorBuffer, _raymarchAvgDepthBuffer.colorBuffer };
            }
            else
            {
                _raymarchColorBuffers[0] = _raymarchedBuffer.colorBuffer;
                _raymarchColorBuffers[1] = _raymarchAvgDepthBuffer.colorBuffer;
            }

            _historyIndex = (_historyIndex + 1) % 2;

            RenderTargetSetup raymarchRenderTargetSetup = new RenderTargetSetup(_raymarchColorBuffers, _raymarchedBuffer.depthBuffer);

            //Pass 0 into raymarched buffer, with regular sampling quality.
            SetKeyword("DOWNSAMPLE_1", _downscaling == 1);
            SetKeyword("DOWNSAMPLE_2", _downscaling == 2);
            material.SetVector("_ProjectionExtents", GetProjectionExtents(camera));
            material.SetFloat("_RaymarchOffset", _lowDiscrepancySequence.GetNextValue());
            material.SetVector("_RaymarchedBuffer_TexelSize", _raymarchedBuffer.texelSize);
            BlitMRT(raymarchRenderTargetSetup, false, material, 0);

            //Pass 1: blending into active history buffer
            if (_isFirstFrame)
            {
                Graphics.Blit(_raymarchedBuffer, _historyDoubleBuffers[_historyIndex]);
                _previousViewMatrix = camera.worldToCameraMatrix;
            }
            material.SetTexture("_RaymarchedBuffer", _raymarchedBuffer);
            material.SetTexture("_RaymarchedAvgDepthBuffer", _raymarchAvgDepthBuffer);
            material.SetMatrix("_PrevVP", GL.GetGPUProjectionMatrix(camera.projectionMatrix, false) * _previousViewMatrix);
            material.SetFloat("_Ln2OverBlendHalfLife", Mathf.Log(2) / _blendHalfLife);

            int historyOtherIndex = (_historyIndex + 1) % 2;
            Graphics.Blit(_historyDoubleBuffers[_historyIndex], _historyDoubleBuffers[historyOtherIndex], material, 1);

            //Pass 2: apply lighting and blend with scene
            material.SetTexture("_CloudDensityTexture", _historyDoubleBuffers[historyOtherIndex]);
            Graphics.Blit(source, destination, material, 2);

            //Cleanup
            _previousViewMatrix = camera.worldToCameraMatrix;
            _isFirstFrame = false;
        }

        protected override void Awake()
        {
            base.Awake();
            _isFirstFrame = true;
        }

        protected override void OnEnable()
        {
            base.OnEnable();
            _isFirstFrame = true;
        }

        /// <summary>Two RenderTextures storing the raymarch history. 
        /// Double-buffered so we can  </summary>
        private RenderTexture[] _historyDoubleBuffers;
        /// <summary> Stores intensity raymarch results calculated for the current frame. </summary>
        private RenderTexture _raymarchedBuffer;
        /// <summary> Stores depth raymarch results calculated for the current frame. </summary>
        private RenderTexture _raymarchAvgDepthBuffer;
        /// <summary> Stores color buffers of raymarch intensity and depth RenderTextures. </summary>
        private RenderBuffer[] _raymarchColorBuffers;
        /// <summary> If this is the first time a frame is being rendered. </summary>
        private bool _isFirstFrame = true;
        /// <summary> Index of the history buffers containing the previous frame's history.</summary>
        private int _historyIndex = 0;
        /// <summary> The previous frame's View matrix for this camera. </summary>
        private Matrix4x4 _previousViewMatrix;
        /// <summary>  </summary>
        private LowDiscrepancySequence _lowDiscrepancySequence = new LowDiscrepancySequence();
    }
}