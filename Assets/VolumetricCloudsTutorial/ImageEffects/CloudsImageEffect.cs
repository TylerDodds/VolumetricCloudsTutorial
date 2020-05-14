using UnityEngine;
using VolumetricCloudsTutorial.Configuration;

namespace VolumetricCloudsTutorial.ImageEffects
{
    /// <summary>
    /// MonoBehaviour for performing clouds image effect in Unity's OnRenderImage
    /// </summary>
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public class CloudsImageEffect : Base.CloudEffectBase
    {
        /// <summary>
        /// Perform the image effect during <see cref="OnRenderImage(RenderTexture, RenderTexture)"/>
        /// </summary>
        /// <param name="material">The material for the effect</param>
        /// <param name="camera">The Camera</param>
        /// <param name="source">The source RenderTexture</param>
        /// <param name="destination">The destination RenderTexture</param>
        protected override void PerformEffect(Material material, Camera camera, RenderTexture source, RenderTexture destination)
        {
            material.SetVector("_ProjectionExtents", GetProjectionExtents(camera));
            Graphics.Blit(source, destination, material, 0);
        }

    }
}