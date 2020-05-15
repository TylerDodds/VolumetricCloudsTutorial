Shader "Hidden/VolumetricCloudsTutorial/CloudImageEffectShader"
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
	#include "DepthSampling.cginc"

	sampler2D_float _CameraDepthTexture;
	uniform float4 _AmbientBottom;
	uniform float4 _AmbientTop;

	/// Perform raymarching in the view direction to determine transmittance and intensity, 
	/// then find final pixel color.
	half4 frag(InterpolatorsUvScreenViewPos i) : SV_Target
	{
		half4 sceneColor = tex2D(_MainTex, i.uv);
		#if UNITY_COLORSPACE_GAMMA
		sceneColor.rgb = GammaToLinearSpace(sceneColor.rgb);
		sceneColor.a = GammaToLinearSpaceExact(sceneColor.a);
		#endif

		float3 viewPos = float3(i.viewRay, 1.0);
		float4 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1.0f));
		worldPos /= worldPos.w;
		float3 rayDirUnNorm = (worldPos.xyz - _WorldSpaceCameraPos);

		float3 worldSpaceDirection;
		const float offset = 0;
		float depthWeight;
		float2 uvDepth = UNITY_PROJ_COORD(i.screenPos);
		float linear01Depth = SampleLinear01Depth(_CameraDepthTexture, uvDepth);
		float4 transmittanceAndIntegratedIntensities = FragmentTransmittanceAndIntegratedIntensitiesAndDepth(linear01Depth, rayDirUnNorm, offset, worldSpaceDirection, depthWeight);

		float4 raymarchColor = RaymarchColorLitAnalyticalTransmittanceIntensity(transmittanceAndIntegratedIntensities, _AmbientBottom, _AmbientTop);

		raymarchColor *= (1 - smoothstep(0, -fadeHorizonAngle, worldSpaceDirection.y));//Multiply by fade-out factor for far-away clouds, acting like 'fade to skybox' (really should fade to atmospheric scattering value).
		//TODO A whole atmospheric scattering solution is needed if we don't wish to perform this simple approximation.

		float4 finalColor = raymarchColor + sceneColor * (1 - raymarchColor.a);//premultiplied alpha
		#if UNITY_COLORSPACE_GAMMA
		finalColor.rgb = LinearToGammaSpace(finalColor.rgb);
		finalColor.a = LinearToGammaSpaceExact(finalColor.a);
		#endif
		return linear01Depth == 1 ? finalColor : sceneColor;
		//TODO Handle clouds in front of transparent objects? do clouds first then skybox 'underneath' with its own separate blending?
	}

	ENDCG
	SubShader
	{
		ZTest Always Cull Off ZWrite Off
		Pass
		{
			CGPROGRAM
			#pragma vertex VertUvScreenViewPos
			#pragma fragment frag
			#pragma multi_compile _ QUALITY_HIGH QUALITY_LOW
			#pragma shader_feature UNPACK_CURL
			#pragma multi_compile _ ADAPTIVE_STEPS
			ENDCG
		}
	}
	Fallback off
}