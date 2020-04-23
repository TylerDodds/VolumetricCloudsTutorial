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

	struct InterpolatorsUvScreenViewPos
	{
		float4 vertex : SV_POSITION;
		float2 uv : TEXCOORD0;
		float4 screenPos : TEXCOORD1;
		float2 viewRay : TEXCOORD2;
	};

	InterpolatorsUvScreenViewPos VertUvScreenViewPos(VertData v)
	{
		InterpolatorsUvScreenViewPos o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = v.uv;
		//Convert screen uv to [-1, 1]x[-1, 1] range, then multiplying by projection extents get the xy components of the view-space ray at depth 1.
		o.viewRay = (2.0 * v.uv - 1.0) * _ProjectionExtents.xy + _ProjectionExtents.zw;
		o.screenPos = ComputeScreenPos(o.vertex);
		return o;
	}

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

			float _RaymarchOffset;

			struct InterpolatorsRaymarch
			{
				float4 vertex : SV_POSITION;
				float4 screenPos : TEXCOORD0;
				float2 viewRay : TEXCOORD1;
			};

			InterpolatorsRaymarch VertRaymarch(VertData v)
			{
				InterpolatorsRaymarch o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.screenPos = ComputeScreenPos(o.vertex);
				o.viewRay = (2.0 * v.uv - 1.0) * _ProjectionExtents.xy + _ProjectionExtents.zw;
				return o;
			}

			struct RaymarchResults
			{
				float4 Target0 : SV_Target0;
				float Target1 : SV_Target1;
			};

			RaymarchResults FragRaymarch(InterpolatorsRaymarch i)
			{
				float2 screenPos = i.screenPos.xy / i.screenPos.w;
				float2 uvDepth = UNITY_PROJ_COORD(screenPos);

				float3 viewPos = float3(i.viewRay, 1.0);
				float4 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1.0f));
				worldPos /= worldPos.w;
				float3 rayDirUnNorm = (worldPos.xyz - _WorldSpaceCameraPos);

				float3 worldSpaceDirection;
				float depthWeight;
				//TODO Bayer offset?
				float offset = -frac(_RaymarchOffset);
				float4 transmittanceAndIntegratedIntensities = FragmentTransmittanceAndIntegratedIntensitiesAndDepth(uvDepth, rayDirUnNorm, offset, _CameraDepthTexture, worldSpaceDirection, depthWeight);

				RaymarchResults results;
				results.Target0 = transmittanceAndIntegratedIntensities;
				results.Target1 = depthWeight;
				return results;
			}

			ENDCG
		}

		//Pass 2 - lighting
		Pass
		{
			CGPROGRAM
			#pragma vertex VertUvScreenViewPos
			#pragma fragment FragLighting

			uniform sampler2D _CloudDensityTexture;
			uniform float4 _AmbientBottom;
			uniform float4 _AmbientTop;

			float4 FragLighting(InterpolatorsUvScreenViewPos i) : SV_Target
			{
				half4 sceneColor = tex2D(_MainTex, i.uv);

				float4 cloudTransmittanceAndIntegratedIntensities = tex2D(_CloudDensityTexture, i.uv);
				float4 raymarchColor = RaymarchColorLitAnalyticalTransmittanceIntensity(cloudTransmittanceAndIntegratedIntensities, _AmbientBottom, _AmbientTop);

				//TODO fade-out factor
				//TODO gamma conversion
				return raymarchColor + sceneColor * (1 - raymarchColor.a);//premultiplied alpha
			}

			ENDCG
		}
	}
	Fallback off
}