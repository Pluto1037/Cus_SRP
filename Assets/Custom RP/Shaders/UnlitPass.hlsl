#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED

// unlit的着色器定义

// #include "../ShaderLibrary/Common.hlsl"

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
// UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// GPU实例化后，顶点着色器输入结构体参数
struct Attributes {
	float3 positionOS : POSITION;
	float2 baseUV : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

// 让顶点着色器同时输出位置和索引
struct Varyings {
	float4 positionCS : SV_POSITION;
	float2 baseUV : VAR_BASE_UV;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

Varyings UnlitPassVertex (Attributes input) {
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input); // 从输入中提取对象索引，并存储在一个全局静态变量中
	UNITY_TRANSFER_INSTANCE_ID(input, output);
	float3 positionWS = TransformObjectToWorld(input.positionOS);
	output.positionCS = TransformWorldToHClip(positionWS);
	// float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	output.baseUV = TransformBaseUV(input.baseUV); // 纹理坐标的缩放和平移
	return output;
}

float4 UnlitPassFragment (Varyings input) : SV_TARGET {
	UNITY_SETUP_INSTANCE_ID(input);

	InputConfig config = GetInputConfig(input.baseUV);
	float4 base = GetBase(config);
	// 裁剪后的片元不透明，结合着色器设置选择是否丢弃
	#if defined(_CLIPPING)
		clip(base.a - GetCutoff(config));
	#endif
	return float4(base.rgb, GetFinalAlpha(base.a));
}

#endif