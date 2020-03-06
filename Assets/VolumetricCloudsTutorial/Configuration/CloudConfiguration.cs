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
        [SerializeField] Texture2D _weatherTexture = null;
        /// <summary> Weather texture (coverage, wetness and cloud type in R, G, B channels respectively). </summary>
        public Texture2D WeatherTexture { get { return _weatherTexture; } }

        [SerializeField] float _cloudScaleKm = 38.0f;
        /// <summary> Overall scale of the clouds pattern. </summary>
        public float CloudScale { get { return _cloudScaleKm * 1000; } }

        [SerializeField] float _weatherScaleKm = 48.0f;
        /// <summary> Overall scale of the weather pattern. </summary>
        public float WeatherScale { get { return _weatherScaleKm * 1000; } }

        [SerializeField] Vector3 _windDirection = new Vector3(1, 0.4f, -1);
        /// <summary> Overall direction of the wind. </summary>
        public Vector3 WindDirection { get { return _windDirection; } }

        [SerializeField] float _windStrength = 100f;
        /// <summary> Strength multiplier for the wind. </summary>
        public float WindStrength { get { return _windStrength; } }

        [SerializeField] [Range(0, 1)] float _windHeightSkewFactor = 0.8f;
        /// <summary> Factor for how clouds are skewed in the wind direction, depending on height. </summary>
        public float WindHeightSkewFactor { get { return _windHeightSkewFactor; } }

        [SerializeField] [Range(0, 1)] float _anvilBias = 0f;
        /// <summary> How much anvil-shaped bias to apply to cloud coverage based on height. </summary>
        public float AnvilBias { get { return _anvilBias; } }

        [SerializeField] [Range(0, 1)] float _cloudCoverageModifier = 1f;
        /// <summary> Multiplier for cloud coverage from weather texture. </summary>
        public float CloudCoverageMultiplier { get { return _cloudCoverageModifier; } }

        [SerializeField] [Range(0, 1)] float _cloudCoverageMin = 0.3f;
        /// <summary> Minimum for cloud coverage from weather texture. </summary>
        public float CloudCoverageMinimum { get { return _cloudCoverageMin; } }

        [SerializeField] [Range(0, 1)] float _cloudDensityCoverageMultiplier = 1f;
        /// <summary> Multiplier for cloud density when determining coverage modification. </summary>
        public float CloudDensityCoverageMultiplier { get { return _cloudDensityCoverageMultiplier; } }

        [SerializeField] [Range(0, 1)] float _cloudTypeMultiplier = 1f;
        /// <summary> Multiplier for cloud density when determining coverage modification. </summary>
        public float CloudTypeMultiplier { get { return _cloudTypeMultiplier; } }

        [Header("Shape")]
        [SerializeField] float _baseDensityTiling = 2;
        /// <summary> Tiling of the base density noise relative to the <see cref="CloudScale"/>. </summary>
        public float BaseDensityTiling { get { return _baseDensityTiling; } }

        [SerializeField] Texture2D _densityErosionTexture = null;
        /// <summary> Texture whose RG channels specify density multiplier and erosion amount over cloud type (X) and height (Y). </summary>
        public Texture2D DensityErosionTexture { get { return _densityErosionTexture; } }

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
            material.SetTexture("_WeatherTex", WeatherTexture);
            material.SetTexture("_DensityErosionTex", DensityErosionTexture);

            material.SetFloat("_CloudScale", CloudScale);
            material.SetFloat("_WeatherScale", WeatherScale);
            material.SetVector("_WindStrengthAndSkew", new Vector4(WindDirection.x, WindDirection.y, WindDirection.z, WindHeightSkewFactor) * WindStrength);
            material.SetFloat("_AnvilBias", AnvilBias);
            material.SetFloat("_CloudCoverageMultiplier", CloudCoverageMultiplier);
            material.SetFloat("_CloudCoverageMinimum", CloudCoverageMinimum);
            material.SetFloat("_CloudDensityCoverageMultiplier", CloudDensityCoverageMultiplier);
            material.SetFloat("_CloudTypeMultiplier", CloudTypeMultiplier);

            material.SetFloat("_BaseDensityTiling", BaseDensityTiling);

            material.SetFloat("_SigmaExtinction", SigmaExtinction);
            material.SetFloat("_SigmaScattering", SigmaScattering);
            material.SetFloat("_CloudDensityOffset", CloudDensityOffset);

            material.SetColor("_AmbientColor", AmbientColor);
        }
    }
}