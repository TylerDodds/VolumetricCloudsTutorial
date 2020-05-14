#if !defined(VCT_VERT_STRUCTURES_INCLUDED)
#define VCT_VERT_STRUCTURES_INCLUDED

#include "UnityCG.cginc"

sampler2D _MainTex;
float4 _MainTex_TexelSize;
float4 _ProjectionExtents;

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

#endif // VCT_VERT_STRUCTURES_INCLUDED