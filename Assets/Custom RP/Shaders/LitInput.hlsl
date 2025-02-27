#ifndef CUSTOM_LIT_INPUT_INCLUDED
#define CUSTOM_LIT_INPUT_INCLUDED

TEXTURE2D(_BaseMap);
TEXTURE2D(_MaskMap);
TEXTURE2D(_EmissionMap);
TEXTURE2D(_NormalMap);
SAMPLER(sampler_BaseMap);

TEXTURE2D(_DetailMap);
TEXTURE2D(_DetailNormalMap);
SAMPLER(sampler_DetailMap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
    UNITY_DEFINE_INSTANCED_PROP(float4, _DetailMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
    UNITY_DEFINE_INSTANCED_PROP(float4, _EmissionColor)
	UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
    UNITY_DEFINE_INSTANCED_PROP(float, _ZWrite)
	UNITY_DEFINE_INSTANCED_PROP(float, _Metallic)
    UNITY_DEFINE_INSTANCED_PROP(float, _Occlusion)
	UNITY_DEFINE_INSTANCED_PROP(float, _Smoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _Fresnel)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailAlbedo)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailSmoothness)
    UNITY_DEFINE_INSTANCED_PROP(float, _DetailNormalScale)
    UNITY_DEFINE_INSTANCED_PROP(float, _NormalScale)

    // Ray Marching
    UNITY_DEFINE_INSTANCED_PROP(float4, _CylinderStart)
    UNITY_DEFINE_INSTANCED_PROP(float4, _CylinderEnd)
    UNITY_DEFINE_INSTANCED_PROP(float, _CylinderRadius)
    // Grid
    UNITY_DEFINE_INSTANCED_PROP(float4, _GridWidthHeight)
    UNITY_DEFINE_INSTANCED_PROP(float4, _WidthHeightSegments)
    // UNITY_DEFINE_INSTANCED_PROP(float, _MaxSteps)
    // UNITY_DEFINE_INSTANCED_PROP(float, _SurfDist)
    // UNITY_DEFINE_INSTANCED_PROP(float, _MaxDist)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

// 定义宏来便捷访问实例化属性
#define INPUT_PROP(name) UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, name)

// 输入配置，不同的输入参数设置
struct InputConfig {
    Fragment fragment;
	float2 baseUV;
	float2 detailUV;
    bool useMask;
    bool useDetail;
};
InputConfig GetInputConfig (float4 positionSS, float2 baseUV, float2 detailUV = 0.0) {
	InputConfig c;
    c.fragment = GetFragment(positionSS);
	c.baseUV = baseUV; 
	c.detailUV = detailUV;
    c.useMask = false;
    c.useDetail = false;
	return c;
}

float2 TransformBaseUV (float2 baseUV) {
	float4 baseST = INPUT_PROP(_BaseMap_ST);
	return baseUV * baseST.xy + baseST.zw;
}

float2 TransformDetailUV (float2 detailUV) {
	float4 detailST = INPUT_PROP(_DetailMap_ST);
	return detailUV * detailST.xy + detailST.zw;
}

float4 GetDetail (InputConfig c) {
    if (c.useDetail) {
        // r通道影响漫反射，b通道影响平滑度，ag通道影响法线的xy分量
        float4 map = SAMPLE_TEXTURE2D(_DetailMap, sampler_DetailMap, c.detailUV);
        return map * 2.0 - 1.0; // 将灰度值转换为[-1, 1]范围
    }
    return 0.0;
}

float4 GetMask (InputConfig c) {
	if (c.useMask) {
		return SAMPLE_TEXTURE2D(_MaskMap, sampler_BaseMap, c.baseUV);
	}
	return 1.0;
}

float4 GetBase (InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, c.baseUV);
	float4 color = INPUT_PROP(_BaseColor);

    if (c.useDetail) {
        float detail = GetDetail(c).r * INPUT_PROP(_DetailAlbedo);
        float mask = GetMask(c).b;
        // 0.5中性
        map.rgb = lerp(sqrt(map.rgb), detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
        map.rgb *= map.rgb; // 近似伽马
    }

	return map * color;
}

float GetCutoff (InputConfig c) {
	return INPUT_PROP(_Cutoff);
}

float GetMetallic (InputConfig c) {
	float metallic = INPUT_PROP(_Metallic);
	metallic *= GetMask(c).r; // 基础设置与掩码叠加
	return metallic;
}

float GetOcclusion (InputConfig c) {
	float strength = INPUT_PROP(_Occlusion);
	float occlusion = GetMask(c).g;
	occlusion = lerp(occlusion, 1.0, strength);
	return occlusion;
}

float GetSmoothness (InputConfig c) {
	float smoothness = INPUT_PROP(_Smoothness);
	smoothness *= GetMask(c).a;

    if (c.useDetail) {
        // 与GetBase同样的方法，叠加细节贴图的平滑度
        float detail = GetDetail(c).b * INPUT_PROP(_DetailSmoothness);
        float mask = GetMask(c).b;
        smoothness = lerp(smoothness, detail < 0.0 ? 0.0 : 1.0, abs(detail) * mask);
    }

	return smoothness;
}

float3 GetEmission (InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_EmissionMap, sampler_BaseMap, c.baseUV);
	float4 color = INPUT_PROP(_EmissionColor);
	return map.rgb * color.rgb;
}

float GetFresnel (InputConfig c) {
	return INPUT_PROP(_Fresnel);
}

float3 GetNormalTS (InputConfig c) {
	float4 map = SAMPLE_TEXTURE2D(_NormalMap, sampler_BaseMap, c.baseUV);
	float scale = INPUT_PROP(_NormalScale);
	float3 normal = DecodeNormal(map, scale);

    if (c.useDetail) {
        // 叠加细节法线
        map = SAMPLE_TEXTURE2D(_DetailNormalMap, sampler_DetailMap, c.detailUV);
        scale = INPUT_PROP(_DetailNormalScale) * GetMask(c).b;
        float3 detail = DecodeNormal(map, scale);
        normal = BlendNormalRNM(normal, detail);
    }

	return normal;
}

float GetFinalAlpha (float alpha) {
	return INPUT_PROP(_ZWrite) ? 1.0 : alpha;
}

// float GetMaxSteps (InputConfig c) {
//     return INPUT_PROP(_MaxSteps);
// }
// float GetSurfDist (InputConfig c) {
//     return INPUT_PROP(_SurfDist);
// }
// float GetMaxDist (InputConfig c) {
//     return INPUT_PROP(_MaxDist);
// }
float3 GetCylinderStart (InputConfig c) {
    return INPUT_PROP(_CylinderStart).xyz;
}
float3 GetCylinderEnd (InputConfig c) {
    return INPUT_PROP(_CylinderEnd).xyz;
}
float GetCylinderRadius (InputConfig c) {
    return INPUT_PROP(_CylinderRadius);
}
float2 GetGridWidthHeight (InputConfig c) {
    return INPUT_PROP(_GridWidthHeight).xy;
}
float2 GetWidthHeightSegments (InputConfig c) {
    return INPUT_PROP(_WidthHeightSegments).xy;
}
#endif