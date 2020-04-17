using UnityEngine;
using VolumetricCloudsTutorial.Configuration;

namespace VolumetricCloudsTutorial.ImageEffects
{
    /// <summary>
    /// Produces a sequence of values in [0,1] that will uniformly cover that range.
    /// </summary>
    public class LowDiscrepancySequence
    {
        //We use a Halton sequence.

        private int _sequenceIndex = 0;
        public int SequenceBase = 3;

        public float GetNextValue()
        {
            float result = GetHaltonValue(_sequenceIndex, SequenceBase);
            _sequenceIndex++;
            return result;
        }

        /// <summary>
        /// Gets a value at a given index of the sequence, with the given base value.
        /// </summary>
        /// <param name="index">Index along the sequence.</param>
        /// <param name="sequenceBase">Base value for Halton sequence.</param>
        /// <returns></returns>
        private static float GetHaltonValue(int index, int sequenceBase)
        {
            float result = 0f;
            float fraction = 1f / (float)sequenceBase;
            while (index > 0)
            {
                result += (float)(index % sequenceBase) * fraction;

                index /= sequenceBase;
                fraction /= (float)sequenceBase;
            }
            return result;
        }
    }
}