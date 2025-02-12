#ifndef CUSTOM_SHADOW_CASTER_PASS_INCLUDED
#define CUSTOM_SHADOW_CASTER_PASS_INCLUDED

// #include "../ShaderLibrary/Common.hlsl"

// RAY MARCHING引入
#include "../ShaderLibrary/RayMarching.hlsl"

// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);

// UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
// 	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
// 	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
// 	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes {
	float3 positionOS : POSITION;
	float2 baseUV : TEXCOORD0;	
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
	#if defined(_RAY_MARCHING)
		float3 positionWS : VAR_POSITION; // 世界空间位置
	#endif
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

bool _ShadowPancaking;

Varyings ShadowCasterPassVertex (Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float3 positionWS = TransformObjectToWorld(input.positionOS);
	output.positionCS = TransformWorldToHClip(positionWS);

	#if defined(_RAY_MARCHING)
		output.positionWS = positionWS;
	#endif

	// 当物体在阴影贴图裁剪空间后时，将其压缩在近平面上来生成阴影
	if (_ShadowPancaking) {
		#if UNITY_REVERSED_Z
			output.positionCS.z = min(
				output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE
			);
		#else
			output.positionCS.z = max(
				output.positionCS.z, output.positionCS.w * UNITY_NEAR_CLIP_VALUE
			);
		#endif
	}

	// float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	output.baseUV = TransformBaseUV(input.baseUV);
	return output;
}

float ShadowCasterPassFragment (Varyings input) : SV_DEPTH {
	UNITY_SETUP_INSTANCE_ID(input);

	ClipLOD(input.positionCS.xy, unity_LODFade.x);

	InputConfig config = GetInputConfig(input.baseUV);

	// ---------------RAY MARCHING----------------
	// 在表面模型前计算RayMarching材质并返回结果
	#if defined(_RAY_MARCHING)
		float3 rayOrigin, rayDirection;
		if(_WorldSpaceLightPos0.z != -1) {
			rayOrigin = input.positionWS;
			rayDirection = normalize(_WorldSpaceLightPos0.xyz);
		}
		else 	discard; // 非单个平行光不渲染阴影贴图
		HitProperties cylinderHitProp = CylinderHit(
			rayOrigin, rayDirection, 
			TransformObjectToWorld(GetCylinderStart(config)), 
			TransformObjectToWorld(GetCylinderEnd(config)), 
			GetCylinderRadius(config)
			);
		if(cylinderHitProp.isHit) {
			input.positionCS = TransformWorldToHClip(cylinderHitProp.hitPoint);
		}
		else	discard;
	#endif
	// -------------------------------------------

	float4 base = GetBase(config);
	#if defined(_SHADOWS_CLIP)
		clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
	#elif defined(_SHADOWS_DITHER)
		float dither = InterleavedGradientNoise(input.positionCS.xy, 0);
		clip(base.a - dither);
	#endif

	return input.positionCS.z;
}

#endif