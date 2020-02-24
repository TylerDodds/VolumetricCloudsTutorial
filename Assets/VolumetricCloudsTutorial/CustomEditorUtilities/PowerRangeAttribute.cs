using UnityEngine;

namespace VolumetricCloudsTutorial.CustomEditorUtilities
{
    /// <summary>
    /// <see cref="PropertyAttribute"/> for giving a range slider whose value follows a power law based on slider position.
    /// </summary>
    public class PowerRangeAttribute : PropertyAttribute
    {
        public float min;
        public float max;
        public float power;

        public PowerRangeAttribute(float min, float max, float power)
        {
            this.min = min;
            this.max = max;
            this.power = power;
        }
    }
}