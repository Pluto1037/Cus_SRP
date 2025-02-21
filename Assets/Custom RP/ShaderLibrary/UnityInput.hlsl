#ifndef CUSTOM_UNITY_INPUT_INCLUDED
#define CUSTOM_UNITY_INPUT_INCLUDED

CBUFFER_START(UnityPerDraw)
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject;
    float4 unity_LODFade; // 开启批处理需要包含的值，LOD淡出
	real4 unity_WorldTransformParams;
	float4 unity_RenderingLayer; // 渲染层蒙版

	real4 unity_LightData; // 灯光索引的相关数据
	real4 unity_LightIndices[2]; // data的y分量记录灯光个数，最多4*2=8个

	float4 unity_ProbesOcclusion; // 获取探针中的阴影遮罩数据
	float4 unity_SpecCube0_HDR;

	float4 unity_LightmapST; // 光照贴图的scale和translation变换
	float4 unity_DynamicLightmapST; // 兼容设置
	// 探针所需的球谐函数信息
	float4 unity_SHAr;
	float4 unity_SHAg;
	float4 unity_SHAb;
	float4 unity_SHBr;
	float4 unity_SHBg;
	float4 unity_SHBb;
	float4 unity_SHC;
	// LPPV探针所需的信息
	float4 unity_ProbeVolumeParams;
	float4x4 unity_ProbeVolumeWorldToObject;
	float4 unity_ProbeVolumeSizeInv;
	float4 unity_ProbeVolumeMin;
CBUFFER_END

float4x4 unity_MatrixVP;
float4x4 unity_MatrixV;
float4x4 unity_MatrixInvV;
float4x4 unity_prev_MatrixM;
float4x4 unity_prev_MatrixIM;
float4x4 glstate_matrix_projection;
float3 _WorldSpaceCameraPos;
float4 _WorldSpaceLightPos0; // 主光源信息：方向光：（世界空间方向，0）。其他光源：（世界空间位置，1）
// 用于控制meta Pass生成的数据
bool4 unity_MetaFragmentControl;
// 提亮diffuse所用内置值
float unity_OneOverOutputBoost;
float unity_MaxOutputValue;
float4 unity_OrthoParams; // 用于正交投影的参数
float4 _ProjectionParams; // _ProjectionParams 向量的X分量指示是否需要手动翻转UV
float4 _ScreenParams; // 根据平面大小参数获取片元的屏幕坐标
float4 _ZBufferParams; // 深度缓冲区参数，包括线性深度缓冲区的参数

#endif