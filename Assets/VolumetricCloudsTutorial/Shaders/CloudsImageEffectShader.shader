Shader "Hidden/VolumetricMedia/CloudOnRenderImageShader"
{
	Properties
	{
		_MainTex("-", 2D) = "" {}
	}

	CGINCLUDE

	#include "VertStructures.cginc"
	#include "FragmentRaymarching.cginc"
	#include "RaymarchColor.cginc"
	#include "NoiseTextureUtil.cginc"

	sampler2D_float _CameraDepthTexture;
	uniform float4 _AmbientColor;

	/// Perform raymarching in the view direction to determine transmittance and intensity, 
	/// then find final pixel color.
	half4 frag(v2f i) : SV_Target
	{
		half4 sceneColor = tex2D(_MainTex, i.uv);

		float3 worldSpaceDirection;
		const float offset = 0;
		float4 transmittanceAndintegratedIntensityAndDepth = FragmentTransmittanceAndIntegratedIntensityAndDepth(i.uv_depth, i.ray, offset, _CameraDepthTexture, worldSpaceDirection);

		fixed3 ambient = _AmbientColor;

		float4 raymarchColor = RaymarchColorLitAnalyticalTransmittanceIntensity(transmittanceAndintegratedIntensityAndDepth, ambient);

		raymarchColor *= (1 - smoothstep(0, -fadeHorizonAngle, worldSpaceDirection.y));//Multiply by fade-out factor for far-away clouds, acting like 'fade to skybox' (really should fade to atmospheric scattering value).
		//TODO A whole atmospheric scattering solution is needed if we don't wish to perform this simple approximation.

		return raymarchColor + sceneColor * (1 - raymarchColor.a);//premultiplied alpha
		//TODO handle clouds in front of transparent objects? do clouds first then skybox 'underneath' with its own separate blending?
	}

	ENDCG
	SubShader
	{
		ZTest Always Cull Off ZWrite Off
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile _ QUALITY_HIGH QUALITY_LOW
			ENDCG
		}
	}
	Fallback off
}