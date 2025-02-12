#ifndef CUSTOM_SURFACE_INCLUDED
#define CUSTOM_SURFACE_INCLUDED

struct Surface {
	float3 position;
	float3 normal;
	float3 interpolatedNormal; // 保留模型的插值法线用于阴影偏移
    float3 viewDirection; // 相机方向
	float depth; // 视口下的深度
	float3 color;
	float alpha;
    // brdf参数
    float metallic;
	float occlusion;
	float smoothness;
	float fresnelStrength;
	float dither; // 抖动
};

#endif