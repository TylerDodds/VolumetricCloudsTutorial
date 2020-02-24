using UnityEngine;
using VolumetricCloudsTutorial.CustomEditorUtilities;

namespace VolumetricCloudsTutorial.Configuration
{
    /// <summary>
    /// <see cref="ScriptableObject"/> containing configuration values and noise textures for clouds rendering.
    /// </summary>
    [CreateAssetMenu(fileName = "CloudConfiguration.asset", menuName = "Volumetric Clouds Tutorial/Configuration")]
    public class CloudConfiguration : ScriptableObject
    {
        [Header("Weather")]
        [SerializeField] float _cloudScaleKm = 38.0f;
        /// <summary> Overall scale of the clouds pattern. </summary>
        public float CloudScale { get { return _cloudScaleKm * 1000; } }

        [Header("Shape")]
        [SerializeField] float _baseDensityTiling = 2;
        /// <summary> Tiling of the base density noise relative to the <see cref="CloudScale"/>. </summary>
        public float BaseDensityTiling { get { return _baseDensityTiling; } }

        [Header("Density/Scattering")]
        [SerializeField] [PowerRange(0.0001f, 1f, 10f)] float _sigmaExtinction = 0.08f;
        /// <summary> The extinction coefficient used during raymarching. </summary>
        public float SigmaExtinction { get { return _sigmaExtinction; } }
        [SerializeField] [PowerRange(0.0001f, 1f, 10f)] float _sigmaScattering = 0.08f;
        /// <summary> The scattering coefficient used during raymarching. </summary>
        public float SigmaScattering { get { return _sigmaScattering; } }
        [SerializeField] [Range(-0.99f, 0.99f)] float _cloudDensityOffset = 0.3f;
        /// <summary> A uniform offset for the base cloud density. </summary>
        public float CloudDensityOffset { get { return _cloudDensityOffset; } }

        [Header("Noise")]
        [SerializeField] Texture3D _baseDensityPerlinWorleyNoisePacked = null;
        /// <summary> The packed noise texture used for the base cloud density. </summary>
        public Texture3D BaseDensityPerlinWorleyNoisePacked { get { return _baseDensityPerlinWorleyNoisePacked; } }

        [Header("Lighting")]
        [SerializeField] Color _ambientColor = new Color(.8f, .8f, .8f);
        public Color AmbientColor { get { return _ambientColor; } }

        /// <summary> Sets cloud shader properties for the given material based on the configuration values. </summary>
        public void SetMaterialProperties(Material material)
        {
            material.SetTexture("_BaseDensityNoise", BaseDensityPerlinWorleyNoisePacked);

            material.SetFloat("_CloudScale", CloudScale);

            material.SetFloat("_BaseDensityTiling", BaseDensityTiling);

            material.SetFloat("_SigmaExtinction", SigmaExtinction);
            material.SetFloat("_SigmaScattering", SigmaScattering);
            material.SetFloat("_CloudDensityOffset", CloudDensityOffset);

            material.SetColor("_AmbientColor", AmbientColor);
        }
    }
}