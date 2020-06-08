using UnityEngine;
using VolumetricCloudsTutorial.Configuration;

namespace VolumetricCloudsTutorial.ImageEffects.Base
{
    /// <summary>
    /// Base MonoBehaviour for performing cloud rendering image effects in Unity's OnRenderImage
    /// </summary>
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public abstract class CloudEffectBase : ImageEffectBase
    {
        /// <summary>
        /// The quality of the raymarch step size (smaller steps for higher quality).
        /// </summary>
        [Tooltip("The quality of the raymarch step size (smaller steps for higher quality).")]
        [SerializeField] private RaymarchStepQuality _raymarchStepQuality = RaymarchStepQuality.Normal;

        /// <summary>
        /// If adaptive step size raymarching should be used.
        /// </summary>
        [Tooltip("If adaptive step size raymarching should be used. Not recommended for Low or Normal quality settings.")]
        [SerializeField] private bool _adaptiveStepSize = false;

        /// <summary>
        /// The <see cref="CloudConfiguration"/> reference containing cloud rendering parameters.
        /// </summary>
        [Tooltip("The CloudConfiguration reference containing cloud rendering parameters.")]
        #pragma warning disable 0649
        [SerializeField] private CloudConfiguration _cloudConfiguration;
        #pragma warning restore 0649

        /// <summary>
        /// Update the image effect's Material before rendering
        /// </summary>
        /// <param name="material">The Material to update</param>
        protected override void UpdateMaterial(Material material)
        {
            SetKeyword("ADAPTIVE_STEPS", _adaptiveStepSize);
            SetKeyword("QUALITY_LOW", _raymarchStepQuality == RaymarchStepQuality.Low);
            SetKeyword("QUALITY_HIGH", _raymarchStepQuality == RaymarchStepQuality.High);
            SetKeyword("QUALITY_EXTREME", _raymarchStepQuality == RaymarchStepQuality.Extreme);
            if (_cloudConfiguration != null)
            {
                _cloudConfiguration.SetMaterialProperties(material);
            }
        }

        private enum RaymarchStepQuality
        {
            Low,
            Normal,
            High,
            Extreme,
        }
    }
}