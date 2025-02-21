#ifndef CUSTOM_COMMON_INCLUDED
#define CUSTOM_COMMON_INCLUDED

// 从unity中获得的一系列宏定义和宏函数，include的包会覆写部分宏定义

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "UnityInput.hlsl"

#define UNITY_MATRIX_M unity_ObjectToWorld
#define UNITY_MATRIX_I_M unity_WorldToObject
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_I_V unity_MatrixInvV // 逆视图矩阵
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_PREV_MATRIX_M unity_prev_MatrixM // 前一帧的模型矩阵，用于TAA
#define UNITY_PREV_MATRIX_I_M unity_prev_MatrixIM // 前一帧的逆模型矩阵
#define UNITY_MATRIX_P glstate_matrix_projection

#if defined(_SHADOW_MASK_ALWAYS) || defined(_SHADOW_MASK_DISTANCE) // 使GPU自动实例化遮挡数据
	#define SHADOWS_SHADOWMASK
#endif

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"

SAMPLER(sampler_linear_clamp);
SAMPLER(sampler_point_clamp);

bool IsOrthographicCamera () {
	return unity_OrthoParams.w;
}
float OrthographicDepthBufferToLinear (float rawDepth) {
	#if UNITY_REVERSED_Z
		rawDepth = 1.0 - rawDepth;
	#endif
	return (_ProjectionParams.z - _ProjectionParams.y) * rawDepth + _ProjectionParams.y;
}


#include "Fragment.hlsl"

// 平方函数
float Square (float v) {
	return v * v;
}
// 两点之间的平方距离
float DistanceSquared(float3 pA, float3 pB) {
	return dot(pA - pB, pA - pB);
}

// 混合LOD
void ClipLOD (Fragment fragment, float fade) {
	#if defined(LOD_FADE_CROSSFADE)
		float dither = InterleavedGradientNoise(fragment.positionSS, 0); // 与半透明阴影相同的模式
		clip(fade + (fade < 0.0 ? dither : -dither));
	#endif
}

// 目标平台影响法线贴图是否压缩，分类解压方法
float3 DecodeNormal (float4 sample, float scale) {
	#if defined(UNITY_NO_DXT5nm)
	    return normalize(UnpackNormalRGB(sample, scale));
	#else
	    return normalize(UnpackNormalmapRGorAG(sample, scale));
	#endif
}

// 将法线从切线空间转换到世界空间
float3 NormalTangentToWorld (float3 normalTS, float3 normalWS, float4 tangentWS) {
	float3x3 tangentToWorld =
		CreateTangentToWorld(normalWS, tangentWS.xyz, tangentWS.w);
	return TransformTangentToWorld(normalTS, tangentToWorld);
}

#endif