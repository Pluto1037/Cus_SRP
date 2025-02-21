Shader "Custom RP/Lit"
{
    Properties
    {
        _BaseMap("Texture", 2D) = "white" {} // white是unity的标准白色纹理，后接代码块曾用于纹理设置，现在兼容无用
        _BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        [Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0 // 关闭裁剪，避免裁剪丢弃片元
        [Toggle(_RECEIVE_SHADOWS)] _ReceiveShadows ("Receive Shadows", Float) = 1 // 是否接收阴影
        [KeywordEnum(On, Clip, Dither, Off)] _Shadows ("Shadows", Float) = 0 // 阴影模式

        // Ray Marching材质
        [HideInInspector][Toggle(_RAY_MARCHING)] _RayMarching("Enable Ray Marching", Float) = 0 // Ray Marching开关
        [HideInInspector][Toggle(_RAY_MARCHING_GRID)] _RayMarchingGrid("Enable Ray Marching Grid", Float) = 0
        [HideInInspector]_CylinderStart("Cylinder Start", Vector) = (0, 0.5, 0) // 圆柱体起始点
        [HideInInspector]_CylinderEnd("Cylinder End", Vector) = (0, -0.5, 0) // 圆柱体结束点
        [HideInInspector]_CylinderRadius("Cylinder Radius", Float) = 0.5 // 圆柱体半径
        [HideInInspector]_GridWidthHeight("Grid Width Height", Vector) = (5, 5, 0) // 栅格长宽
        [HideInInspector]_WidthHeightSegments("Width Height Segments", Vector) = (2, 2, 0) // 栅格分段数
        // _MaxSteps("MaxSteps", float) = 100 // 步进最大次数
        // _SurfDist("SurfDists", float) = 0.001 // 距离容差值
        // _MaxDist("MaxDist", float) = 100 // 步进的最远距离

        // Metallic, Occlusion, Detail, Smoothness 四合一MODS<掩码>贴图
        // 关闭sRGB选项以取消GPU采样时的Gamma校正
        [Toggle(_MASK_MAP)] _MaskMapToggle ("Mask Map", Float) = 0
        [NoScaleOffset] _MaskMap("Mask (MODS)", 2D) = "white" {}
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Occlusion ("Occlusion", Range(0, 1)) = 1
		_Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _Fresnel ("Fresnel", Range(0, 1)) = 1
        
        // 手动控制相关贴图的采样，减少计算量
        [Toggle(_NORMAL_MAP)] _NormalMapToggle ("Normal Map", Float) = 0
        [NoScaleOffset] _NormalMap("Normals", 2D) = "bump" {}
		_NormalScale("Normal Scale", Range(0, 1)) = 1
        [NoScaleOffset] _EmissionMap("Emission", 2D) = "white" {}
		[HDR] _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)

        [Toggle(_DETAIL_MAP)] _DetailMapToggle ("Detail Maps", Float) = 0
        _DetailMap("Details", 2D) = "linearGrey" {}
        [NoScaleOffset] _DetailNormalMap("Detail Normals", 2D) = "bump" {}
        _DetailAlbedo("Detail Albedo", Range(0, 1)) = 1
        _DetailSmoothness("Detail Smoothness", Range(0, 1)) = 1
        _DetailNormalScale("Detail Normal Scale", Range(0, 1)) = 1

        [Toggle(_PREMULTIPLY_ALPHA)] _PremulAlpha ("Premultiply Alpha", Float) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1
	    [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0
        [Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1

        [HideInInspector] _MainTex("Texture for Lightmap", 2D) = "white" {}
		[HideInInspector] _Color("Color for Lightmap", Color) = (0.5, 0.5, 0.5, 1.0)
    }
    SubShader
    {
        // 在所有Pass前都会Include这部分代码
        HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "LitInput.hlsl"
		ENDHLSL
        Pass
        {
            Tags {
				"LightMode" = "CustomLit"
			}
            // 区分Alpha和颜色的混合方式
            Blend [_SrcBlend] [_DstBlend], One OneMinusSrcAlpha
            ZWrite [_ZWrite]

            HLSLPROGRAM
            #pragma target 3.5 // 避免编译OpenGL ES 2.0版本
            #pragma shader_feature _CLIPPING // 根据属性设置编译着色器的不同版本
            #pragma shader_feature _PREMULTIPLY_ALPHA // 是否预乘alpha
            #pragma shader_feature _RECEIVE_SHADOWS // 是否接收阴影
            #pragma shader_feature _NORMAL_MAP // 是否使用法线贴图
            #pragma shader_feature _MASK_MAP // 是否使用MODS贴图
            #pragma shader_feature _DETAIL_MAP // 是否使用细节贴图

            #pragma shader_feature _RAY_MARCHING // 是否RAY MARCHING材质
            #pragma shader_feature _RAY_MARCHING_GRID // 网格状的圆柱RM

            #pragma multi_compile _ _DIRECTIONAL_PCF3 _DIRECTIONAL_PCF5 _DIRECTIONAL_PCF7
            #pragma multi_compile _ _CASCADE_BLEND_SOFT _CASCADE_BLEND_DITHER
            #pragma multi_compile _ _SHADOW_MASK_ALWAYS _SHADOW_MASK_DISTANCE
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma multi_compile _ LIGHTMAP_ON // 开启后Unity将使用具有LIGHTMAP_ON关键字的着色器变体渲染光照贴图对象
            #pragma multi_compile _ _LIGHTS_PER_OBJECT // Lighting中设置的光照索引模式
            #pragma multi_compile _ _OTHER_PCF3 _OTHER_PCF5 _OTHER_PCF7 // 其他光源阴影的过滤等级
            #pragma multi_compile_instancing
            #pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
			#include "LitPass.hlsl"
            ENDHLSL
        }
        Pass {
			Tags {
				"LightMode" = "ShadowCaster"
			}

			ColorMask 0 // 不写入颜色

			HLSLPROGRAM
			#pragma target 3.5
			#pragma shader_feature _ _SHADOWS_CLIP _SHADOWS_DITHER
            #pragma shader_feature _RAY_MARCHING // 是否RAY MARCHING材质
            #pragma shader_feature _RAY_MARCHING_GRID // 网格状的圆柱RM
            #pragma multi_compile _ LOD_FADE_CROSSFADE
			#pragma multi_compile_instancing
			#pragma vertex ShadowCasterPassVertex
			#pragma fragment ShadowCasterPassFragment
			#include "ShadowCasterPass.hlsl"
			ENDHLSL
		}
        Pass {
			Tags {
				"LightMode" = "Meta"
			}

			Cull Off

			HLSLPROGRAM
			#pragma target 3.5
			#pragma vertex MetaPassVertex
			#pragma fragment MetaPassFragment
			#include "MetaPass.hlsl"
			ENDHLSL
		}
    }
    // 指示Unity使用CustomShaderGUI类的实例来绘制Lit着色器的检查器
    CustomEditor "CustomShaderGUI" 
}
