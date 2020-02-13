using UnityEngine;
using System;
#if UNITY_EDITOR
using UnityEditor;
#endif

namespace VolumetricCloudsTutorial.ImageEffects.Base
{
    public static class TextureSplit
    {
        #if UNITY_EDITOR
        /// <summary>
        /// Sets the maximum teture size of the selected Texture2D to 16384.
        /// </summary>
        [MenuItem("Tools/Textures/Set Max Size To 16384")]
        public static void SetMaxSize()
        {
            UnityEngine.Object activeObject = Selection.activeObject;
            if (activeObject.GetType() == typeof(Texture2D))
            {
                int systemMaxSize = SystemInfo.maxTextureSize;
                int desiredSize = 16384;

                if(systemMaxSize >= desiredSize)
                {
                    Texture2D tex = activeObject as Texture2D;
                    string texPath = AssetDatabase.GetAssetPath(activeObject);
                    TextureImporter texImp = AssetImporter.GetAtPath(texPath) as TextureImporter;
                    if (texImp != null)
                    {
                        texImp.maxTextureSize = 16384;
                        texImp.SaveAndReimport();
                    }
                }
                else
                {
                    Debug.LogWarningFormat("System max texture size {0} is less than {1}", systemMaxSize, desiredSize);
                }
            }
        }

        /// <summary>
        /// Splits the selected Texture2D into a Texture3D asset and saves it at a user-specified location in the project.
        /// Requires the texture to be N^2 x N in size, and splits every N x N chunk in the horizontal direction into a layer of the Texture3D.
        /// </summary>
        [MenuItem("Tools/Textures/Split Texture2D To Texture3D Cube")]
        public static void SplitSelectedTexture()
        {
            UnityEngine.Object activeObject = Selection.activeObject;
            if (activeObject.GetType() == typeof(Texture2D))
            {
                Texture2D tex2D = (Texture2D)activeObject;
                Texture3D tex3D = SplitTiledTexture(tex2D, mipmap: true);
                if (tex3D != null)
                {
                    string message = "Save Split Texture";
                    string filePath = EditorUtility.SaveFilePanelInProject(message, "SplitTexture", "asset", message);
                    if (!string.IsNullOrEmpty(filePath))
                    {
                        AssetDatabase.CreateAsset(tex3D, filePath);
                        AssetDatabase.SaveAssets();
                    }
                }
            }
        }
#endif

        /// <summary>
        /// Splits the given Texture2D into a Texture3D.
        /// Requires the texture to be N^2 x N in size, and splits every N x N chunk in the horizontal direction into a layer of the Texture3D.
        /// </summary>
        /// <param name="texture2D">The input <see cref="Texture2D"/>.</param>
        /// <param name="mipmap">If the resulting texture should have Mipmaps generated.</param>
        /// <returns>The split <see cref="Texture3D"/>.</returns>
        public static Texture3D SplitTiledTexture(Texture2D texture2D, bool mipmap)
        {
            var width = texture2D.width;
            var height = texture2D.height;
            bool tiledAlongX = width >= height;
            var side = Mathf.Min(width, height);
            var longSide = Mathf.Max(width, height);
            int tiling = longSide / side;

            if (longSide % side != 0)
            {
                throw new ArgumentException(string.Format("Side length {0} does not divide longer length {1} evenly.", side, longSide));
            }

            var pixels2D = texture2D.GetPixels32();
            var reordered = ReorderPixels(pixels2D, side, tiling, tiledAlongX);

            var tex3D = new Texture3D(side, side, tiling, texture2D.format, mipmap);

            tex3D.SetPixels32(reordered);
            tex3D.Apply();

            return tex3D;
        }

        /// <summary>
        /// Reorders an input pixel array corresponding to a input texture (consisting of repeated tiled square sub-images) to match the order required for a split Texture3D.
        /// </summary>
        /// <param name="pixels2D">The input array of <see cref="Color32"/> values.</param>
        /// <param name="side">The side length.</param>
        /// <param name="tiling">The amount of tiled (side x side size) images stored in the original texture.</param>
        /// <param name="tiledAlongX">If the image is tiled horizontally.</param>
        /// <returns>A pixel array of <see cref="Color32"/> values in the order required for a split Texture3D.</returns>
        private static Color32[] ReorderPixels(Color32[] pixels2D, int side, int tiling, bool tiledAlongX)
        {
            if (!tiledAlongX)
            {
                throw new NotImplementedException("Slicing assumes image is tiled along x-axis.");
            }

            Color32[] ordered = new Color32[pixels2D.Length];
            int longSide = side * tiling;

            for (int index = 0; index < pixels2D.Length; index++)
            {
                //Note that for original image, index = x + y * side * tiling
                int xOrig = index % longSide;
                int yOrig = index / longSide;

                Color32 color = pixels2D[index];

                int whichTile = xOrig / side;
                int xInTile = xOrig % side;

                int xNew = xInTile;
                int yNew = yOrig;
                int zNew = whichTile;

                //Note that in 3D texture, x is always the inner index
                //So, index = x + y * side + z * side * side

                int indexNew = xNew + yNew * side + zNew * side * side;

                ordered[indexNew] = color;
            }

            return ordered;
        }
    }
}