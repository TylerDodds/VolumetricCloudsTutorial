using UnityEngine;
using VolumetricCloudsTutorial.Configuration;

namespace VolumetricCloudsTutorial.ImageEffects
{
    /// <summary>
    /// MonoBehaviour for performing clouds image effect in Unity's OnRenderImage
    /// </summary>
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public class CloudsHistoryEffect : Base.ImageEffectBase
    {
        [SerializeField] [Range(0, 2)] private int _downsample;

        [SerializeField] private CloudConfiguration _cloudConfiguration;

        /// <summary>
        /// Update the image effect's Material before rendering
        /// </summary>
        /// <param name="material">The Material to update</param>
        protected override void UpdateMaterial(Material material)
        {
            if (_cloudConfiguration != null)
            {
                _cloudConfiguration.SetMaterialProperties(material);
            }
        }

        /// <summary>
        /// Perform the image effect during <see cref="OnRenderImage(RenderTexture, RenderTexture)"/>
        /// </summary>
        /// <param name="material">The material for the effect</param>
        /// <param name="camera">The Camera</param>
        /// <param name="source">The source RenderTexture</param>
        /// <param name="destination">The destination RenderTexture</param>
        protected override void PerformEffect(Material material, Camera camera, RenderTexture source, RenderTexture destination)
        {
            //TODO
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
        /// <summary> Stores intensity and depth raymarch results calculated for the current frame. </summary>
        private RenderTexture _raymarchedBuffer;
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