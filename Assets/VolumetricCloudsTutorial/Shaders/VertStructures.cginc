#if !defined(VCT_VERT_STRUCTURES_INCLUDED)
#define VCT_VERT_STRUCTURES_INCLUDED

#include "UnityCG.cginc"

sampler2D _MainTex;
float4 _MainTex_TexelSize;

/// Vertex structure for image effects, including main texture UV, depth UV, and camera view ray (packed into normals of the input).
struct v2f
{
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float2 uv_depth : TEXCOORD1;
	float3 ray : TEXCOORD2;
};

v2f vert(appdata_full v)
{
	v2f o;

	o.pos = UnityObjectToClipPos(v.vertex);
	o.uv = v.texcoord.xy;
	o.uv_depth = v.texcoord.xy;
	o.ray = v.texcoord1.xyz;

	//See https://docs.unity3d.com/Manual/SL-PlatformDifferences.html
	#if UNITY_UV_STARTS_AT_TOP
	if (_MainTex_TexelSize.y < 0.0) o.uv.y = 1.0 - o.uv.y;
	#endif

	return o;
}

#endif // VCT_VERT_STRUCTURES_INCLUDED