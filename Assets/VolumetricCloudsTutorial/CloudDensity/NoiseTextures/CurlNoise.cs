using UnityEngine;
using System;
using System.Linq;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace VolumetricCloudsTutorial.ImageEffects.Base
{
    public static class CurlNoise
    {
#if UNITY_EDITOR
        /// <summary>
        /// Generates a three-channel curl texture from a selected base <see cref="Texture2D"/>.
        /// Requires the texture to have three channels of noise representing three components of the base vector field.
        /// </summary>
        [MenuItem("Tools/Textures/Generate RGB Curl Noise From Selected Texture")]
        public static void RGBCurlNoiseFromSelectedTexture()
        {
            CurlNoiseFromSelectedTexture(true);
        }

        /// <summary>
        /// Generates a two-channel curl texture from a selected base <see cref="Texture2D"/>.
        /// Requires the texture to have three channels of noise representing three components of the base vector field.
        /// </summary>
        [MenuItem("Tools/Textures/Generate RG Curl Noise From Selected Texture")]
        public static void RGCurlNoiseFromSelectedTexture()
        {
            CurlNoiseFromSelectedTexture(false);
        }

        /// <summary>
        /// Generates a curl texture from a selected base <see cref="Texture2D"/>.
        /// Requires the texture to have three channels of noise representing three components of the base vector field.
        /// </summary>
        /// <param name="threeChannelsOut">If the curl will have values in three channels instead of two.</param>
        private static void CurlNoiseFromSelectedTexture(bool threeChannelsOut)
        {
            UnityEngine.Object activeObject = Selection.activeObject;
            if (activeObject != null && activeObject.GetType() == typeof(Texture2D))
            {
                Texture2D tex2D = (Texture2D)activeObject;
                Texture2D curlTexture = CreateCurlNoiseFromSelectedTexture(tex2D, threeChannelsOut, mipmap: true, uniformScaling: true);
                if (curlTexture != null)
                {
                    string message = "Save Curl Texture";
                    string defaultName = "CurlTexture" + (threeChannelsOut ? "RGB" : "RG");
                    string filePath = EditorUtility.SaveFilePanelInProject(message, defaultName, "asset", message);
                    if (!string.IsNullOrEmpty(filePath))
                    {
                        AssetDatabase.CreateAsset(curlTexture, filePath);
                        AssetDatabase.SaveAssets();
                    }
                }
            }
        }
#endif

        /// <summary>
        /// Generates a curl texture from a base <see cref="Texture2D"/>.
        /// Requires the texture to have three channels of noise representing three components of the base vector field.
        /// </summary>
        /// <param name="baseTexture">The input <see cref="Texture2D"/>.</param>
        /// <param name="threeChannelsOut">If the curl will have values in three channels instead of two.</param>
        /// <param name="mipmap">If the resulting texture should have Mipmaps generated.</param>
        /// <param name="uniformScaling">If all three channels should be rescaled into the same range, instead of on a per-channel basis.</param>
        /// <returns>The generated curl <see cref="Texture3D"/>.</returns>
        public static Texture2D CreateCurlNoiseFromSelectedTexture(Texture2D baseTexture, bool threeChannelsOut, bool mipmap, bool uniformScaling)
        {
            int width = baseTexture.width;
            int height = baseTexture.height;
            Texture2D curlTexture = new Texture2D(width, height, threeChannelsOut ? TextureFormat.RGB24 : TextureFormat.RGFloat, mipmap);

            Color[] pixels = baseTexture.GetPixels(0, 0, width, height);
            int GetIndex(int x, int y) => y * width + x;
            Vector3 GetChannels(int x, int y) => (Vector4)pixels[GetIndex(x, y)];

            Vector3[] curlValues = new Vector3[pixels.Length];
            void SetColor(int x, int y, Vector3 value) => curlValues[GetIndex(x, y)] = value;

            for (int x = 0; x < width; x++)
            {
                for (int y = 0; y < height; y++)
                {
                    int xPlusOne = (x + 1) % width;
                    int xMinusOne = (x - 1 + width) % width;
                    int yPlusOne = (y + 1) % height;
                    int yMinusOne = (y - 1 + height) % height;

                    Vector3 deltaX = GetChannels(xPlusOne, y) - GetChannels(xMinusOne, y);
                    Vector3 deltaY = GetChannels(x, yPlusOne) - GetChannels(x, yMinusOne);
                    Vector3 gradientX = deltaX / (2.0f / width);
                    Vector3 gradientY = deltaY / (2.0f / height);

                    //Curl is (δFz/δy - δFy/δz, δFx/δz - δFz/δx, δFy/δx - δFx/δy)
                    //Here we assume gradient w.r.t. z-direction is zero
                    Vector3 curl = new Vector3(gradientY.z, -gradientX.z, gradientX.y - gradientY.x);

                    SetColor(x, y, curl);
                }
            }

            //Rescale components so we can pack into uniform range
            var minR = curlValues.Min(v => v.x);
            var minG = curlValues.Min(v => v.y);
            var minB = curlValues.Min(v => v.z);
            var maxR = curlValues.Max(v => v.x);
            var maxG = curlValues.Max(v => v.y);
            var maxB = curlValues.Max(v => v.z);
            float GetMaxAbsScale(float a, float b) => Mathf.Max(0.0000001f, Mathf.Max(Mathf.Abs(a), Mathf.Abs(b)));
            var scaleR = GetMaxAbsScale(minR, maxR);
            var scaleG = GetMaxAbsScale(minG, maxG);
            var scaleB = GetMaxAbsScale(minB, maxB);
            if (uniformScaling)
            {
                var maxScale = Mathf.Max(Mathf.Max(scaleR, scaleG), scaleB);
                scaleR = maxScale;
                scaleG = maxScale;
                scaleB = maxScale;
            }

            Color[] finalValues = new Color[curlValues.Length];
            for(int i = 0; i < curlValues.Length; i++)
            {
                Vector3 curl = curlValues[i];
                curl.x /= scaleR;
                curl.y /= scaleG;
                curl.z /= scaleB;
                if (threeChannelsOut)
                {
                    Vector3 encoded = 0.5f * (curl + Vector3.one);
                    Color encodedColor = new Color(encoded.x, encoded.y, encoded.z, 1);
                    finalValues[i] = encodedColor;
                }
                else
                {
                    finalValues[i] = new Vector4(curl.x, curl.y, 0, 0);
                }
            }

            curlTexture.SetPixels(finalValues);
            curlTexture.Apply();

            return curlTexture;
        }
    }
}
