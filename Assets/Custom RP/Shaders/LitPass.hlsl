#ifndef CUSTOM_LIT_PASS_INCLUDED
#define CUSTOM_LIT_PASS_INCLUDED

/**
* lit的着色器定义
*/

// 展开库中的函数和结构体
// #include "../ShaderLibrary/Common.hlsl"

// 注意包含顺序
#include "../ShaderLibrary/Surface.hlsl"
#include "../ShaderLibrary/Shadows.hlsl"
#include "../ShaderLibrary/Light.hlsl" 
#include "../ShaderLibrary/BRDF.hlsl"
#include "../ShaderLibrary/GI.hlsl"
#include "../ShaderLibrary/Lighting.hlsl"

// RAY MARCHING引入
#include "../ShaderLibrary/RayMarching.hlsl"

// 利用两个宏来定义纹理变量与采样器
// TEXTURE2D(_BaseMap);
// SAMPLER(sampler_BaseMap);

// 更通用的cbuffer定义，批处理颜色缓冲区
// CBUFFER_START(UnityPerMaterial)
// 	float4 _BaseColor;
// CBUFFER_END
// 支持每个实例的材料数据不同
// UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
// 	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST) //unity通过与纹理同名的_ST后缀提供纹理的scale和translation
// 	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
// 	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff) // 透明度截断系数，透明度小于系数的像素被丢弃
// 	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
// 	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// GPU实例化后，顶点着色器输入结构体参数
struct Attributes {
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float4 tangentOS : TANGENT;
	float2 baseUV : TEXCOORD0;
	GI_ATTRIBUTE_DATA // 转移实例标识符？
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 让顶点着色器同时输出位置和索引
struct Varyings {
	float4 positionCS : SV_POSITION; // 裁剪空间位置
	float3 positionWS : VAR_POSITION; // 世界空间位置
	float3 normalWS : VAR_NORMAL;
	#if defined(_NORMAL_MAP)
		float4 tangentWS : VAR_TANGENT;
	#endif
	float2 baseUV : VAR_BASE_UV;
	float2 detailUV : VAR_DETAIL_UV;
	GI_VARYINGS_DATA
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings LitPassVertex (Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input); // 从输入中提取对象索引，并存储在一个全局静态变量中
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	TRANSFER_GI_DATA(input, output);
	output.positionWS = TransformObjectToWorld(input.positionOS);
	output.positionCS = TransformWorldToHClip(output.positionWS);
	output.normalWS = TransformObjectToWorldNormal(input.normalOS);

	#if defined(_NORMAL_MAP)
		output.tangentWS = float4(
			TransformObjectToWorldDir(input.tangentOS.xyz), input.tangentOS.w
		);
	#endif

	output.baseUV = TransformBaseUV(input.baseUV); // 纹理坐标的缩放和平移

	#if defined(_DETAIL_MAP)
		output.detailUV = TransformDetailUV(input.baseUV);
	#endif

	return output;
}

float4 LitPassFragment (Varyings input) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(input);
	ClipLOD(input.positionCS.xy, unity_LODFade.x);

	InputConfig config = GetInputConfig(input.baseUV);
	#if defined(_MASK_MAP)
		config.useMask = true;
	#endif
	#if defined(_DETAIL_MAP)
		config.detailUV = input.detailUV;
		config.useDetail = true;
	#endif

	float4 base = GetBase(config);
	// 裁剪后的片元不透明，结合着色器设置选择是否丢弃
	#if defined(_CLIPPING)
		clip(base.a - GetCutoff(config));
	#endif

	// ---------------RAY MARCHING----------------
	// 在表面模型前计算RayMarching材质并返回结果
	#if defined(_RAY_MARCHING)
		float3 rayOrigin = _WorldSpaceCameraPos;		
		float3 rayDirection = normalize(input.positionWS - rayOrigin);
		rayOrigin = input.positionWS;
		HitProperties cylinderHitProp = CylinderHit(
			rayOrigin, rayDirection, 
			TransformObjectToWorld(GetCylinderStart(config)), 
			TransformObjectToWorld(GetCylinderEnd(config)), 
			GetCylinderRadius(config)
		);
		if(!cylinderHitProp.isHit)
			discard;
		// 启用RayMarching后，覆盖世界坐标和法线
		input.positionWS = cylinderHitProp.hitPoint;
		input.normalWS = cylinderHitProp.hitNormal; 
	#endif
	// -------------------------------------------

	Surface surface;
	surface.position = input.positionWS;
	#if defined(_NORMAL_MAP)
		surface.normal = NormalTangentToWorld(
			GetNormalTS(config), input.normalWS, input.tangentWS
		);
		surface.interpolatedNormal = input.normalWS;
	#else
		surface.normal = normalize(input.normalWS);
		surface.interpolatedNormal = surface.normal;
	#endif
	// 启用RayMarching后，覆盖世界坐标和法线
	// #if defined(_RAY_MARCHING)
	// 	surface.position = cylinderHitProp.hitPoint;
	// 	surface.normal = normalize(cylinderHitProp.hitNormal);
	// 	surface.interpolatedNormal = surface.normal;
	// #endif
	// 世界空间下的摄像机方向
	surface.viewDirection = normalize(_WorldSpaceCameraPos - input.positionWS);
	surface.depth = -TransformWorldToView(input.positionWS).z;
	surface.color = base.rgb;
	surface.alpha = base.a;
	surface.metallic = GetMetallic(config);
	surface.occlusion = GetOcclusion(config);
	surface.smoothness = GetSmoothness(config);
	surface.fresnelStrength = GetFresnel(config);
	surface.dither = InterleavedGradientNoise(input.positionCS.xy, 0); // 根据屏幕空间中的XY位置生成旋转平铺的抖动图案

	#if defined(_PREMULTIPLY_ALPHA)
		BRDF brdf = GetBRDF(surface, true);
	#else
		BRDF brdf = GetBRDF(surface);
	#endif

	GI gi = GetGI(GI_FRAGMENT_DATA(input), surface, brdf);
	float3 color = GetLighting(surface, brdf, gi);
	color += GetEmission(config);
	return float4(color, surface.alpha);
}

#endif