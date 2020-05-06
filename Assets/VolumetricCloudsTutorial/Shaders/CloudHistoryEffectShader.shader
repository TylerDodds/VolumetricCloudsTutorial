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
			#pragma multi_compile _ ADAPTIVE_STEPS

			float _RaymarchOffset; //Fractional offset along first step; changes every frame to avoid biased sampling
			float2 _RaymarchedBuffer_TexelSize;	//Texel size of final buffer used to detemine neighbour offset from Bayer Matrix
			//Dithering matrix for local relative offsets of raymarch position
			static const float _bayerOffsets[3][3] =
			{
				{0, 7, 3},
				{6, 5, 2},
				{4, 1, 8}
			};

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
				float2 uvDepth = UNITY_PROJ_COORD(i.screenPos);

				float3 viewPos = float3(i.viewRay, 1.0);
				float4 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1.0f));
				worldPos /= worldPos.w;
				float3 rayDirUnNorm = (worldPos.xyz - _WorldSpaceCameraPos);

				int2 pixelId = int2(fmod(screenPos / _RaymarchedBuffer_TexelSize, 3));//Repeating 0,1,2 pattern in x and y
				float bayerOffset = _bayerOffsets[pixelId.x][pixelId.y] / 9.0;//Determines fractional offset from Bayer dithering matrix
				float offset = -frac(_RaymarchOffset + bayerOffset);
				float3 worldSpaceDirection;
				float depthWeight;
				float4 transmittanceAndIntegratedIntensities = FragmentTransmittanceAndIntegratedIntensitiesAndDepth(uvDepth, rayDirUnNorm, offset, _CameraDepthTexture, worldSpaceDirection, depthWeight);
				float fadeFactor = (1 - smoothstep(0, -fadeHorizonAngle, worldSpaceDirection.y));
				transmittanceAndIntegratedIntensities.gba *= fadeFactor;
				transmittanceAndIntegratedIntensities.r = 1 - (1 - transmittanceAndIntegratedIntensities.r) * fadeFactor;//Multiply opacity (1 - transmittance) by fadeFactor

				RaymarchResults results;
				results.Target0 = transmittanceAndIntegratedIntensities;
				results.Target1 = depthWeight;
				return results;
			}

			ENDCG
		}

		//Pass 1 - update history buffer
		Pass
		{
			CGPROGRAM

			#pragma vertex VertUvScreenViewPos
			#pragma fragment FragHistory

			uniform sampler2D _RaymarchedBuffer;
			uniform sampler2D _RaymarchedAvgDepthBuffer;
			uniform float4 _RaymarchedBuffer_TexelSize;
			uniform float4x4 _PrevVP;

			//Gets the uv of the world position with respect to the previous view-projection matrix.
			//Also return how far (in unit square coordinates) the uv is outside of the unit square.
			float2 GetPrevUV(float4 worldPos, out float outOfBB)
			{
				float4 prevProjPos = mul(_PrevVP, worldPos);
				float2 uv = 0.5 * (prevProjPos.xy / prevProjPos.w) + 0.5;
				half maxDistPastBBCorner = max(uv.x - 1.0, uv.y - 1.0);
				half maxDistBeforeBBCorner = max(0.0 - uv.x, 0.0 - uv.y);
				outOfBB = max(maxDistBeforeBBCorner, maxDistPastBBCorner);
				return uv;
			}

			//If outside the AABB, moves value towards center until it lies on surface.
			float4 ClipTowardsAABB(float4 center, float4 extents, float4 value)
			{
				float4 diff = value - center;
				float4 diffUnit = diff / extents;
				float4 diffUnitAbs = abs(diffUnit);
				float diffUnitAbsMax = max(diffUnitAbs.x, max(diffUnitAbs.y, max(diffUnitAbs.z, diffUnitAbs.w)));
				if (diffUnitAbsMax > 1.0)
				{
					return center + diff / diffUnitAbsMax;
				}
				else
				{
					return value;
				}
			}

			float4 FragHistory(InterpolatorsUvScreenViewPos i) : SV_Target
			{
				float3 viewPos = float3(i.viewRay, 1.0);
				float4 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1.0f));
				worldPos /= worldPos.w;

				//Get pass 0 raymarched result and depth
				float4 raymarchResult = tex2D(_RaymarchedBuffer, i.uv);
				float raymarchAvgDepthResult = tex2D(_RaymarchedAvgDepthBuffer, i.uv);
				float distance = raymarchAvgDepthResult;

				//Get result from other history buffer
				float4 worldPosAtDistance = mul(unity_CameraToWorld, float4(normalize(viewPos) * distance, 1.0));

				float outOfProjectionBB;
				float2 historyBufferUV = GetPrevUV(worldPosAtDistance, outOfProjectionBB);
				float4 prevSample = tex2D(_MainTex, historyBufferUV);

				//Get raymarch buffer local AABB for the four sample components
				float2 raymarchXOffset = float2(_RaymarchedBuffer_TexelSize.x, 0);
				float2 raymarchYOffset = float2(0, _RaymarchedBuffer_TexelSize.y);

				//Approximate first and second moments by sampling a 3x3 pattern of the current frame's raymarched results
				float4 firstMoment = 0.0, secondMoment = 0.0;
				[unroll]
				for (int dx = -1; dx <= 1; dx++)
				{
					[unroll]
					for (int dy = -1; dy <= 1; dy++)
					{
						float4 offsetSampled;
						if (dx == 0 && dy == 0)
						{
							offsetSampled = raymarchResult;
						}
						else
						{
							offsetSampled = tex2Dlod(_RaymarchedBuffer, float4(i.uv + raymarchXOffset * dx + raymarchYOffset * dy, 0.0, 0.0));
						}
						firstMoment += offsetSampled;
						secondMoment += offsetSampled * offsetSampled;
					}
				}
				firstMoment /= 9.0;
				secondMoment /= 9.0;
				float4 variance = secondMoment - firstMoment * firstMoment;
				float4 stdDev = sqrt(max(0.0, variance));
				const float gamma = 1.5;
				prevSample = ClipTowardsAABB(firstMoment, gamma * stdDev, prevSample);
				//If sample is too far in value from thosea round in, clip it to a bounding box based on average and standard deviation.

				//Determine how far out of bounds, and blend accordingly.
				const float historyMinUpdateFraction = 0.05;//TODO Parametrize
				float4 blendedSample = lerp(prevSample, raymarchResult, max(historyMinUpdateFraction, step(0, outOfProjectionBB)));//TODO Better blending?

				return blendedSample;
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
				#if UNITY_COLORSPACE_GAMMA
				sceneColor.rgb = GammaToLinearSpace(sceneColor.rgb);
				sceneColor.a = GammaToLinearSpaceExact(sceneColor.a);
				#endif

				float4 cloudTransmittanceAndIntegratedIntensities = tex2D(_CloudDensityTexture, i.uv);
				float4 raymarchColor = RaymarchColorLitAnalyticalTransmittanceIntensity(cloudTransmittanceAndIntegratedIntensities, _AmbientBottom, _AmbientTop);

				float4 finalColor = raymarchColor + sceneColor * (1 - raymarchColor.a);//premultiplied alpha
				#if UNITY_COLORSPACE_GAMMA
				finalColor.rgb = LinearToGammaSpace(finalColor.rgb);
				finalColor.a = LinearToGammaSpaceExact(finalColor.a);
				#endif
				return finalColor;
			}

			ENDCG
		}
	}
	Fallback off
}