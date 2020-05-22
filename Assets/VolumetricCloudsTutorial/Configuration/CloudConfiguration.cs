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
        [Tooltip("R, G, and B channels encode coverage, wetness and cloud type respectively).")]
        [SerializeField] Texture2D _weatherTexture = null;
        /// <summary> Weather texture (coverage, wetness and cloud type in R, G, B channels respectively). </summary>
        public Texture2D WeatherTexture { get { return _weatherTexture; } }

        [Tooltip("Overall scale of the clouds pattern.")]
        [SerializeField] float _cloudScaleKm = 38.0f;
        /// <summary> Overall scale of the clouds pattern. </summary>
        public float CloudScale { get { return _cloudScaleKm * 1000; } }

        [Tooltip("Overall scale of the weather pattern.")]
        [SerializeField] float _weatherScaleKm = 48.0f;
        /// <summary> Overall scale of the weather pattern. </summary>
        public float WeatherScale { get { return _weatherScaleKm * 1000; } }

        [Tooltip("Direction of the wind.")]
        [SerializeField] Vector3 _windDirection = new Vector3(1, 0.4f, -1);
        /// <summary> Direction of the wind. </summary>
        public Vector3 WindDirection { get { return _windDirection; } }

        [Tooltip("Strength multiplier for the wind.")]
        [SerializeField] float _windStrength = 100f;
        /// <summary> Strength multiplier for the wind. </summary>
        public float WindStrength { get { return _windStrength; } }

        [Tooltip("Factor for how clouds are skewed in the wind direction, depending on height.")]
        [SerializeField] [Range(0, 1)] float _windHeightSkewFactor = 0.2f;
        /// <summary> Factor for how clouds are skewed in the wind direction, depending on height. </summary>
        public float WindHeightSkewFactor { get { return _windHeightSkewFactor; } }

        [Tooltip("How much anvil-shaped bias to apply to cloud coverage based on height.")]
        [SerializeField] [Range(0, 1)] float _anvilBias = 0f;
        /// <summary> How much anvil-shaped bias to apply to cloud coverage based on height. </summary>
        public float AnvilBias { get { return _anvilBias; } }

        [Tooltip("plier for cloud coverage from weather texture.")]
        [SerializeField] [Range(0, 1)] float _cloudCoverageModifier = 1f;
        /// <summary> Multiplier for cloud coverage from weather texture. </summary>
        public float CloudCoverageMultiplier { get { return _cloudCoverageModifier; } }

        [Tooltip("Minimum for cloud coverage from weather texture.")]
        [SerializeField] [Range(0, 1)] float _cloudCoverageMin = 0.3f;
        /// <summary> Minimum for cloud coverage from weather texture. </summary>
        public float CloudCoverageMinimum { get { return _cloudCoverageMin; } }

        [Tooltip("Multiplier for cloud density when determining coverage modification.")]
        [SerializeField] [Range(0, 1)] float _cloudDensityCoverageMultiplier = 1f;
        /// <summary> Multiplier for cloud density when determining coverage modification. </summary>
        public float CloudDensityCoverageMultiplier { get { return _cloudDensityCoverageMultiplier; } }

        [Tooltip("Multiplier for cloud density when determining coverage modification.")]
        [SerializeField] [Range(0, 1)] float _cloudTypeMultiplier = 1f;
        /// <summary> Multiplier for cloud density when determining coverage modification. </summary>
        public float CloudTypeMultiplier { get { return _cloudTypeMultiplier; } }

        [Header("Shape")]
        [Tooltip("Tiling of the base density noise relative to the CloudScale.")]
        [SerializeField] float _baseDensityTiling = 2;
        /// <summary> Tiling of the base density noise relative to the <see cref="CloudScale"/>. </summary>
        public float BaseDensityTiling { get { return _baseDensityTiling; } }

        [Tooltip("RG channels specify density multiplier and erosion amount over cloud type (X) and height (Y).")]
        [SerializeField] Texture2D _densityErosionTexture = null;
        /// <summary> Texture whose RG channels specify density multiplier and erosion amount over cloud type (X) and height (Y). </summary>
        public Texture2D DensityErosionTexture { get { return _densityErosionTexture; } }

        [Tooltip("Tiling of the detail density noise relative to the CloudScale.")]
        [SerializeField] float _detailTiling = 40f;
        /// <summary> Tiling of the detail density noise relative to the <see cref="CloudScale"/>. </summary>
        public float DetailTiling { get { return _detailTiling; } }

        [Tooltip("Strength of remapping of base density from detail density.")]
        [SerializeField] [Range(0, 1)] float _detailStrength = 0.2f;
        /// <summary> Strength of remapping of base density from detail density. </summary>
        public float DetailStrength { get { return _detailStrength; } }

        [Tooltip("Tiling of curl noise relative to the CloudScale.")]
        [SerializeField] [PowerRange(0.001f, 10f, 10f)] float _curlTiling = 0.01f;
        /// <summary> Tiling of curl noise relative to the <see cref="CloudScale"/>. </summary>
        public float CurlTiling { get { return _curlTiling; } }

        [Tooltip("Strength of curl noise offset of detail density sampling.")]
        [SerializeField] [Range(0, 0.1f)] float _curlStrength = 0.05f;
        /// <summary> Strength of curl noise offset of detail density sampling. </summary>
        public float CurlStrength { get { return _curlStrength; } }


        [Header("Density/Scattering")]
        [Tooltip("The extinction coefficient used during raymarching.")]
        [SerializeField] [PowerRange(0.0001f, 1f, 10f)] float _sigmaExtinction = 0.08f;
        /// <summary> The extinction coefficient used during raymarching. </summary>
        public float SigmaExtinction { get { return _sigmaExtinction; } }

        [Tooltip("The scattering coefficient used during raymarching.")]
        [SerializeField] [PowerRange(0.0001f, 1f, 10f)] float _sigmaScattering = 0.08f;
        /// <summary> The scattering coefficient used during raymarching. </summary>
        public float SigmaScattering { get { return _sigmaScattering; } }

        [Tooltip("A uniform offset for the base cloud density.")]
        [SerializeField] [Range(-0.99f, 0.99f)] float _cloudDensityOffset = 0.3f;
        /// <summary> A uniform offset for the base cloud density. </summary>
        public float CloudDensityOffset { get { return _cloudDensityOffset; } }

        [Tooltip("A uniform scaling for the final cloud density.")]
        [SerializeField] [PowerRange(0.01f, 2, 10)] float _finalDensityScale = 1f;
        /// <summary> A uniform scaling for the final cloud density. </summary>
        public float FinalDensityScale { get { return _finalDensityScale; } }

        [Header("Noise")]
        [Tooltip("The packed noise texture used for the base cloud density.")]
        [SerializeField] Texture3D _baseDensityNoisePacked = null;
        /// <summary> The packed noise texture used for the base cloud density. </summary>
        public Texture3D BaseDensityNoisePacked { get { return _baseDensityNoisePacked; } }

        [Tooltip("The packed noise texture used for the detail cloud density.")]
        [SerializeField] Texture3D _detailDensityNoisePacked = null;
        /// <summary> The packed noise texture used for the detail cloud density. </summary>
        public Texture3D DetailDensityNoisePacked { get { return _detailDensityNoisePacked; } }

        [Tooltip("The curl noise used to offset the sample position for the detail cloud density.")]
        [SerializeField] Texture2D _curlNoise = null;
        /// <summary> The curl noise used to offset the sample position for the detail cloud density. </summary>
        public Texture2D CurlNoise { get { return _curlNoise; } }

        [Header("Lighting")]
        [Tooltip("The base (smallest) step size used in self-shadowing transmittance estimation.")]
        [SerializeField] [PowerRange(2, 2048, 2)] float _shadowStepBase = 32f;
        /// <summary> The base (smallest) step size used in self-shadowing transmittance estimation. </summary>
        public float ShadowStepBase { get { return _shadowStepBase; } }

        [Tooltip("Eccentricity representing foward-scattering lobe of scattering phase function.")]
        [SerializeField] [Range(0, 1)] float _eccentricityForwards = 0.8f;
        /// <summary> Eccentricity representing foward-scattering lobe of scattering phase function. </summary>
        public float EccentricityForwards { get { return _eccentricityForwards; } }

        [Tooltip("")]
        [SerializeField] [Range(-0.5f, 0.5f)] float _eccentricityBackwards = 0.1f;
        /// <summary> Eccentricity representing backward-scattering lobe of scattering phase function. </summary>
        public float EccentricityBackwards { get { return _eccentricityBackwards; } }

        [Tooltip("Multiplicative factor for extinction for each successive octave of the multi-scattering approximation.")]
        [SerializeField] [Range(0, 1)] float _multiScatteringExtinctionFactor = 0.5f;
        /// <summary> Multiplicative factor for extinction for each successive octave of the multi-scattering approximation. </summary>
        public float MultiScatteringExtinctionFactor { get { return _multiScatteringExtinctionFactor; } }

        [Tooltip("Multiplicative factor for eccentricity for each successive octave of the multi-scattering approximation.")]
        [SerializeField] [Range(0, 1)] float _multiScatteringEccentricityFactor = 0.5f;
        /// <summary> Multiplicative factor for eccentricity for each successive octave of the multi-scattering approximation. </summary>
        public float MultiScatteringEccentricityFactor { get { return _multiScatteringEccentricityFactor; } }

        [Tooltip("Multiplicative factor for light intensity for each successive octave of the multi-scattering approximation.")]
        [SerializeField] [Range(0, 1)] float _multiScatteringIntensityFactor = 0.5f;
        /// <summary> Multiplicative factor for light intensity for each successive octave of the multi-scattering approximation. </summary>
        public float MultiScatteringIntensityFactor { get { return _multiScatteringIntensityFactor; } }

        [Tooltip("Atmospheric height fraction where height scattering rate starts increasing.")]
        [SerializeField] [Range(0, 1)] float _heightScatteringLowFraction = 0.07f;
        /// <summary> Atmospheric height fraction where height scattering rate starts increasing. </summary>
        public float HeightScatteringLowFraction { get { return _heightScatteringLowFraction; } }

        [Tooltip("Atmospheric height fraction where height scattering rate stops increasing.")]
        [SerializeField] [Range(0, 1)] float _heightScatteringHighFraction = 0.14f;
        /// <summary> Atmospheric height fraction where height scattering rate stops increasing. </summary>
        public float HeightScatteringHighFraction { get { return _heightScatteringHighFraction; } }

        [Tooltip("Minimumm height scattering probability.")]
        [SerializeField] [Range(0, 1)] float _heightScatteringMinProbability = 0.2f;
        /// <summary> Minimumm height scattering probability. </summary>
        public float HeightScatteringMinProbability { get { return _heightScatteringMinProbability; } }

        [Tooltip("Power of atmospheric height fraction used in height scattering probability.")]
        [SerializeField] [Range(0, 3)] float _heightScatteringPower = 0.7f;
        /// <summary> Power of atmospheric height fraction used in height scattering probability. </summary>
        public float HeightScatteringPower { get { return _heightScatteringPower; } }

        [Tooltip("Atmospheric height fraction where depth scattering power starts increasing.")]
        [SerializeField] [Range(0, 1)] float _depthScatteringLowFraction = 0.3f;
        /// <summary> Atmospheric height fraction where depth scattering power starts increasing. </summary>
        public float DepthScatteringLowFraction { get { return _depthScatteringLowFraction; } }

        [Tooltip("Atmospheric height fraction where depth scattering power stops increasing.")]
        [SerializeField] [Range(0, 1)] float _depthScatteringHighFraction = 0.85f;
        /// <summary> Atmospheric height fraction where depth scattering power stops increasing. </summary>
        public float DepthScatteringHighFraction { get { return _depthScatteringHighFraction; } }

        [Tooltip("Depth scattering power at the chosen minimum height.")]
        [SerializeField] [Range(0, 2)] float _depthScatteringMinPower = 0.5f;
        /// <summary> Depth scattering power at the chosen minimum height. </summary>
        public float DepthScatteringMinPower { get { return _depthScatteringMinPower; } }

        [Tooltip("Depth scattering power at the chosen maximum height.")]
        [SerializeField] [Range(0, 2)] float _depthScatteringMaxPower = 2.0f;
        /// <summary> Depth scattering power at the chosen maximum height. </summary>
        public float DepthScatteringMaxPower { get { return _depthScatteringMaxPower; } }

        [Tooltip("Ambient light color coming from below the clouds.")]
        [SerializeField] [ColorUsage(false, true)] Color _ambientBottom = new Color(.2f, .2f, .2f);
        /// <summary> Ambient light color coming from below the clouds. </summary>
        public Color AmbientBottom { get { return _ambientBottom; } }

        [Tooltip("Ambient light color coming from above the clouds.")]
        [SerializeField] [ColorUsage(false, true)] Color _ambientTop = new Color(.25f, .25f, .15f);
        /// <summary> Ambient light color coming from above the clouds. </summary>
        public Color AmbientTop { get { return _ambientTop; } }

        [Tooltip("Fraction of full scattering intensity used for wet clouds.")]
        [SerializeField] [Range(0, 1)] float _wetIntensityFraction = 0.3f;
        /// <summary> Fraction of full scattering intensity used for wet clouds. </summary>
        public float WetIntensityFraction { get { return _wetIntensityFraction; } }

        /// <summary> Sets cloud shader properties for the given material based on the configuration values. </summary>
        public void SetMaterialProperties(Material material)
        {
            material.SetTexture("_BaseDensityNoise", BaseDensityNoisePacked);
            material.SetTexture("_DetailDensityNoise", DetailDensityNoisePacked);
            material.SetTexture("_WeatherTex", WeatherTexture);
            material.SetTexture("_DensityErosionTex", DensityErosionTexture);
            material.SetTexture("_CurlTex", CurlNoise);
            if(CurlNoise != null && (CurlNoise.format == TextureFormat.RGB24 || CurlNoise.format == TextureFormat.RGBA32))
            {
                material.EnableKeyword(_unpackCurlKeyword);
            }
            else
            {
                material.DisableKeyword(_unpackCurlKeyword);
            }

            material.SetFloat("_CloudScale", CloudScale);
            material.SetFloat("_WeatherScale", WeatherScale);
            material.SetVector("_WindStrengthAndSkew", new Vector4(WindDirection.x, WindDirection.y, WindDirection.z, WindHeightSkewFactor) * WindStrength);
            material.SetFloat("_AnvilBias", AnvilBias);
            material.SetFloat("_CloudCoverageMultiplier", CloudCoverageMultiplier);
            material.SetFloat("_CloudCoverageMinimum", CloudCoverageMinimum);
            material.SetFloat("_CloudDensityCoverageMultiplier", CloudDensityCoverageMultiplier);
            material.SetFloat("_CloudTypeMultiplier", CloudTypeMultiplier);

            material.SetFloat("_BaseDensityTiling", BaseDensityTiling);
            material.SetFloat("_DetailTiling", DetailTiling);
            material.SetFloat("_DetailStrength", DetailStrength);
            material.SetFloat("_CurlTiling", CurlTiling);
            material.SetFloat("_CurlStrength", CurlStrength);

            material.SetFloat("_ShadowStepBase", ShadowStepBase);
            material.SetFloat("_SigmaExtinction", SigmaExtinction);
            material.SetFloat("_SigmaScattering", SigmaScattering);
            material.SetFloat("_CloudDensityOffset", CloudDensityOffset);
            material.SetFloat("_FinalDensityScale", FinalDensityScale);

            material.SetFloat("_EccentricityForwards", EccentricityForwards);
            material.SetFloat("_EccentricityBackwards", EccentricityBackwards);
            material.SetFloat("_WetIntensityFraction", WetIntensityFraction);
            material.SetVector("_MultiScatteringFactors_Extinction_Eccentricity_Intensity", new Vector4(MultiScatteringExtinctionFactor, MultiScatteringEccentricityFactor, MultiScatteringIntensityFactor, 0));
            material.SetVector("_HeightScattering_Low_High_Min_Power", new Vector4(HeightScatteringLowFraction, HeightScatteringHighFraction, HeightScatteringMinProbability, HeightScatteringPower));
            material.SetVector("_DepthScattering_Low_High_Min_Max", new Vector4(DepthScatteringLowFraction, DepthScatteringHighFraction, DepthScatteringMinPower, DepthScatteringMaxPower));
            material.SetColor("_AmbientBottom", AmbientBottom);
            material.SetColor("_AmbientTop", AmbientTop);
        }

        private const string _unpackCurlKeyword = "UNPACK_CURL";
    }
}
