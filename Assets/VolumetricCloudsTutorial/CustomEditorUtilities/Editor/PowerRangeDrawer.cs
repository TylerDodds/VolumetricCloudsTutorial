using UnityEngine;
using UnityEditor;

namespace VolumetricCloudsTutorial.CustomEditorUtilities.Editor
{
    /// <summary>
    /// <see cref="PropertyDrawer"/> for <see cref="PowerRangeAttribute"/>.
    /// </summary>
    [CustomPropertyDrawer(typeof(PowerRangeAttribute))]
    public class PowerRangeDrawer : PropertyDrawer
    {
        // Draw the property inside the given rect
        public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
        {
            PowerRangeAttribute range = attribute as PowerRangeAttribute;

            // Draw the property as a Slider or an IntSlider based on whether it's a float or integer.
            if (property.propertyType == SerializedPropertyType.Float)
            {
                Slider(position, property, range.min, range.max, range.power, label);
            }
            else if (property.propertyType == SerializedPropertyType.Integer)
            {
                EditorGUI.IntSlider(position, property, (int)range.min, (int)range.max, label);
            }
            else
            {
                EditorGUI.LabelField(position, label.text, "Use Range with float or int.");
            }
        }

        public static void Slider(Rect position, SerializedProperty property, float leftValue, float rightValue, float power, GUIContent label)
        {
            label = EditorGUI.BeginProperty(position, label, property);
            EditorGUI.BeginChangeCheck();
            float num = PowerSlider(position, label, property.floatValue, leftValue, rightValue, power);

            if (EditorGUI.EndChangeCheck())
                property.floatValue = num;
            EditorGUI.EndProperty();
        }

        public static float PowerSlider(Rect position, GUIContent label, float value, float leftValue, float rightValue, float power)
        {
            var editorGuiType = typeof(EditorGUI);
            var methodInfo = editorGuiType.GetMethod(
                "PowerSlider",
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static,
                null,
                new[] { typeof(Rect), typeof(GUIContent), typeof(float), typeof(float), typeof(float), typeof(float) },
                null);
            if (methodInfo != null)
            {
                return (float)methodInfo.Invoke(null, new object[] { position, label, value, leftValue, rightValue, power });
            }
            return leftValue;
        }
    }
}