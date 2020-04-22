Shader "Hidden/VolumetricCloudsTutorial/CloudHistoryEffectShader"
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
	float4 _ProjectionExtents; //For computing view-space ray

	struct VertData
	{
		float4 vertex : POSITION;
		float2 uv : TEXCOORD0;
	};

	ENDCG
	SubShader
	{
		Cull Off ZWrite Off ZTest Always

		//Pass 0 - regular quality raymarching
		Pass
		{
			CGPROGRAM
			#pragma vertex VertRaymarch
			#pragma fragment FragRaymarch
			#pragma multi_compile _ QUALITY_HIGH QUALITY_LOW
			#pragma shader_feature UNPACK_CURL

			struct Interpolators
			{
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float2 viewRay : TEXCOORD1;
			};

			Interpolators VertRaymarch(VertData v)
			{
				Interpolators o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				v.vertex.z = 0.5;
				o.screenPos = ComputeScreenPos(o.vertex);
				o.viewRay = (2.0 * v.uv - 1.0) * _ProjectionExtents.xy + _ProjectionExtents.zw;
				return o;
			}

			struct RaymarchResults
			{
				float4 target00 : SV_Target0;
				float target01 : SV_Target1;
			};

			RaymarchResults FragRaymarch(Interpolators i)
			{
				float2 screenPos = i.screenPos.xy / i.screenPos.w;
				float2 uvDepth = UNITY_PROJ_COORD(screenPos);

				float3 viewPos = float3(i.viewRay, 1.0);
				float4 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1.0f));
				worldPos /= worldPos.w;
				float3 rayDirUnNorm = (worldPos.xyz - _WorldSpaceCameraPos);

				float3 worldSpaceDirection;
				const float offset = 0;
				float depthWeight;
				float4 transmittanceAndIntegratedIntensities = FragmentTransmittanceAndIntegratedIntensitiesAndDepth(uvDepth, rayDirUnNorm, offset, _CameraDepthTexture, worldSpaceDirection, depthWeight);

				RaymarchResults results;
				results.target00 = transmittanceAndIntegratedIntensities;
				results.target01 = depthWeight;
				return results;
			}

			ENDCG
		}
	}
	Fallback off
}