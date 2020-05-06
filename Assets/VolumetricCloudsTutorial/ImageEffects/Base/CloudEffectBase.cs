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
        /// If adaptive step size raymarching should be used.
        /// </summary>
        [SerializeField] private bool _adaptiveStepSize = false;

        /// <summary>
        /// The <see cref="CloudConfiguration"/> reference containing cloud rendering parameters.
        /// </summary>
        [SerializeField] private CloudConfiguration _cloudConfiguration;

        /// <summary>
        /// Update the image effect's Material before rendering
        /// </summary>
        /// <param name="material">The Material to update</param>
        protected override void UpdateMaterial(Material material)
        {
            SetKeyword("ADAPTIVE_STEPS", _adaptiveStepSize);
            if (_cloudConfiguration != null)
            {
                _cloudConfiguration.SetMaterialProperties(material);
            }
        }
    }
}