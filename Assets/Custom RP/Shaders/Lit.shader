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
        [HideInInspector][Toggle(_RAY_MARCHING_PARAL)] _RayMarchingParal("Enable Ray Marching Paral", Float) = 0
        [HideInInspector][Toggle(_RAY_MARCHING_ARC)] _RayMarchingArc("Enable Ray Marching Arc", Float) = 0
        [HideInInspector][Toggle(_RAY_MARCHING_COLUMN)] _RayMarchingColumn("Enable Ray Marching Column", Float) = 0
        [HideInInspector][Toggle(_RAY_MARCHING_QUADRA)] _RayMarchingQuadra("Enable Ray Marching Quadra", Float) = 0
        [HideInInspector]_CylinderStart("Cylinder Start", Vector) = (0, 0.5, 0) // 圆柱体起始点
        [HideInInspector]_CylinderEnd("Cylinder End", Vector) = (0, -0.5, 0) // 圆柱体结束点
        [HideInInspector]_CylinderRadius("Cylinder Radius", Float) = 0.5 // 圆柱体半径
        [HideInInspector]_GridWidthHeight("Grid Width Height", Vector) = (5, 5, 0) // 栅格长宽
        [HideInInspector]_WidthHeightSegments("Width Height Segments", Vector) = (2, 2, 0) // 栅格分段数
        [HideInInspector]_ArcRadius("Arc Radius", Float) = 0.5 // 圆弧半径
        [HideInInspector]_ColumnLengthWidthHeight("Column Length Width Height", Vector) = (1, 1, 2) // 柱状长宽高
        [HideInInspector]_VerticalSegments("Vertical Segments", Float) = 1 // 纵向分割数
        [HideInInspector]_SecondaryCylinderRadius("Secondary Cylinder Radius", Float) = 0.1 // 柱状横向圆柱体半径
        [HideInInspector]_QuadraticConfig("Quadratic Config", Vector) = (1, 0, 0) // 柱状长宽高
        // 无缩放矩阵预计算
        // [HideInInspector]_RotationMatrix("Rotation Matrix", Matrix) = {} // 物体到世界坐标系的变换矩阵
        // [HideInInspector]_InverseRotationMatrix("Inverse Roatation Matrix", Matrix) = {} // 世界到物体坐标系的变换矩阵
        // [HideInInspector]_WorldPosition("World Position", Matrix) = {} // 世界到物体坐标系的变换矩阵的转置矩阵
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
            #pragma shader_feature _RAY_MARCHING_PARAL // 一组平行的圆柱RM
            #pragma shader_feature _RAY_MARCHING_ARC // 圆弧RM
            #pragma shader_feature _RAY_MARCHING_COLUMN // 柱状RM
            #pragma shader_feature _RAY_MARCHING_QUADRA // 二次曲线RM

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
            #pragma shader_feature _RAY_MARCHING_PARAL // 网格状的圆柱RM
            #pragma shader_feature _RAY_MARCHING_ARC // 圆弧RM
            #pragma shader_feature _RAY_MARCHING_COLUMN // 柱状RM
            #pragma shader_feature _RAY_MARCHING_QUADRA // 二次曲线RM
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

    // RayTracing材质
    SubShader
    {
        HLSLINCLUDE
		#include "../ShaderLibrary/Common.hlsl"
		#include "LitInput.hlsl"
		ENDHLSL
        Pass
        {
            Name "RayTracing"
            Tags { 
                "LightMode" = "RayTracing" 
            }

            HLSLPROGRAM

            #pragma raytracing test

            #pragma shader_feature _RAY_MARCHING // 是否RAY MARCHING材质
            #pragma shader_feature _RAY_MARCHING_GRID // 网格状的圆柱RM
            #pragma shader_feature _RAY_MARCHING_PARAL // 一组平行的圆柱RM
            #pragma shader_feature _RAY_MARCHING_ARC // 圆弧RM
            #pragma shader_feature _RAY_MARCHING_COLUMN // 柱状RM
            #pragma shader_feature _RAY_MARCHING_QUADRA // 二次曲线RM

            #include "../ShaderLibrary/RTCommon.hlsl"
            #include "../ShaderLibrary/RayMarching.hlsl"
            #include "../ShaderLibrary/RMNewtonian.hlsl"

            // 用于BRDF着色
            #include "../ShaderLibrary/Surface.hlsl"
            #include "../ShaderLibrary/Shadows.hlsl"
            #include "../ShaderLibrary/Light.hlsl" 
            #include "../ShaderLibrary/BRDF.hlsl"

            struct IntersectionVertex
            {
                // Object space normal of the vertex
                float3 normalOS;
            };

            void FetchIntersectionVertex(uint vertexIndex, out IntersectionVertex outVertex)
            {
                outVertex.normalOS = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributeNormal);
            }

            inline float3 BackgroundColor(float3 direction)
            {
                float t = 0.5f * (direction.y + 1.0f); 
                return (1.0f - t) * float3(1.0f, 1.0f, 1.0f) + t * float3(0.5f, 0.7f, 1.0f);
            }

            [shader("closesthit")]
            void ClosestHitShader(inout RayIntersection rayIntersection : SV_RayPayload, AttributeData attributeData : SV_IntersectionAttributes)
            {
                // Fetch the indices of the currentr triangle
                uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());

                // Fetch the 3 vertices
                IntersectionVertex v0, v1, v2;
                FetchIntersectionVertex(triangleIndices.x, v0);
                FetchIntersectionVertex(triangleIndices.y, v1);
                FetchIntersectionVertex(triangleIndices.z, v2);

                // Compute the full barycentric coordinates
                float3 barycentricCoordinates = float3(1.0 - attributeData.barycentrics.x - attributeData.barycentrics.y, attributeData.barycentrics.x, attributeData.barycentrics.y);

                float3 normalOS = INTERPOLATE_RAYTRACING_ATTRIBUTE(v0.normalOS, v1.normalOS, v2.normalOS, barycentricCoordinates);
                float3x3 objectToWorld = (float3x3)ObjectToWorld3x4();
                float3 normalWS = normalize(mul(objectToWorld, normalOS));

                // rayIntersection.color = float4(0.5f * (normalWS + 1.0f), 0);
                
                // 光源参数
                float3 origin = WorldRayOrigin();
                float3 direction = WorldRayDirection();
                float t = RayTCurrent();
                float3 positionWS = origin + direction * t;

                // 光线前进时累积的结果，记录在intersection的结果中
                // float4 color = INPUT_PROP(_BaseColor);
                float4 color = float4(BackgroundColor(direction), 1.0f);

                if (rayIntersection.remainingDepth > 0)
                {
                    // 透过当前表面的光线信息
                    RayDesc rayDescriptor;
                    rayDescriptor.Origin = positionWS;
                    rayDescriptor.Direction = direction;
                    rayDescriptor.TMin = 1e-5f;
                    rayDescriptor.TMax = _CameraFarDistance;
                    // 下一个迭代的光线信息
                    RayIntersection reflectionRayIntersection;
                    reflectionRayIntersection.remainingDepth = rayIntersection.remainingDepth - 1;
                    reflectionRayIntersection.color = INPUT_PROP(_BaseColor); // 初始颜色为材质颜色

                    // 求交测试，通过则取消下一步递归计算，否则透过当前表面
                    #if defined(_RAY_MARCHING)
                        HitProperties cylinderHitProp = IntersectCylinderNumerical(
                            origin, direction, 
                            TransformObjectToWorld(INPUT_PROP(_CylinderStart)), 
                            TransformObjectToWorld(INPUT_PROP(_CylinderEnd)), 
                            INPUT_PROP(_CylinderRadius)
                        );
                        if(!cylinderHitProp.isHit){
                            // 未命中覆盖为背景颜色
                            reflectionRayIntersection.color = float4(BackgroundColor(direction), 1.0f);
                            TraceRay(_AccelerationStructure, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFF, 0, 1, 0, rayDescriptor, reflectionRayIntersection);
                        }
                        else{
                            // 构建BRDF表面
                            Surface surface;
                            surface.color = INPUT_PROP(_BaseColor).rgb;
                            surface.alpha = INPUT_PROP(_BaseColor).a;                           
                            surface.metallic = INPUT_PROP(_Metallic);
                            surface.smoothness = INPUT_PROP(_Smoothness);
                            surface.position = cylinderHitProp.hitPoint;
                            surface.viewDirection = -direction;
                            surface.normal = cylinderHitProp.hitNormal;
                            BRDF brdf = GetBRDF(surface);

                            // 利用BRDF着色覆盖结果
                            reflectionRayIntersection.color = float4(RTDirectBRDF(surface, brdf), 1.0f);
                        }
                    #endif
                    #if defined(_RAY_MARCHING_GRID)
                        HitProperties cylinderHitProp = GridHit(
                            origin, direction, 
                            INPUT_PROP(_GridWidthHeight).xy,
                            INPUT_PROP(_WidthHeightSegments).xy, 
                            INPUT_PROP(_CylinderRadius)
                        );
                        if(!cylinderHitProp.isHit){
                            // 未命中覆盖为背景颜色
                            reflectionRayIntersection.color = float4(BackgroundColor(direction), 1.0f);
                            TraceRay(_AccelerationStructure, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFF, 0, 1, 0, rayDescriptor, reflectionRayIntersection);
                        }
                        else{
                            // 构建BRDF表面
                            Surface surface;
                            surface.color = INPUT_PROP(_BaseColor).rgb;
                            surface.alpha = INPUT_PROP(_BaseColor).a;                           
                            surface.metallic = INPUT_PROP(_Metallic);
                            surface.smoothness = INPUT_PROP(_Smoothness);
                            surface.position = cylinderHitProp.hitPoint;
                            surface.viewDirection = -direction;
                            surface.normal = cylinderHitProp.hitNormal;
                            BRDF brdf = GetBRDF(surface);

                            // 利用BRDF着色覆盖结果
                            reflectionRayIntersection.color = float4(RTDirectBRDF(surface, brdf), 1.0f);
                        }
                    #endif
                    #if defined(_RAY_MARCHING_PARAL)
                        HitProperties cylinderHitProp = ParalHit(
                            origin, direction, 
                            INPUT_PROP(_GridWidthHeight),
                            INPUT_PROP(_WidthHeightSegments).xy, // 仅使用WidthSegments
                            INPUT_PROP(_CylinderRadius)
                        );
                        if(!cylinderHitProp.isHit){
                            // 未命中覆盖为背景颜色
                            reflectionRayIntersection.color = float4(BackgroundColor(direction), 1.0f);
                            TraceRay(_AccelerationStructure, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFF, 0, 1, 0, rayDescriptor, reflectionRayIntersection);
                        }
                        else{
                            // 构建BRDF表面
                            Surface surface;
                            surface.color = INPUT_PROP(_BaseColor).rgb;
                            surface.alpha = INPUT_PROP(_BaseColor).a;                           
                            surface.metallic = INPUT_PROP(_Metallic);
                            surface.smoothness = INPUT_PROP(_Smoothness);
                            surface.position = cylinderHitProp.hitPoint;
                            surface.viewDirection = -direction;
                            surface.normal = cylinderHitProp.hitNormal;
                            BRDF brdf = GetBRDF(surface);

                            // 利用BRDF着色覆盖结果
                            reflectionRayIntersection.color = float4(RTDirectBRDF(surface, brdf), 1.0f);
                        }
                    #endif
                    #if defined(_RAY_MARCHING_ARC)
                        HitProperties cylinderHitProp = PhantomTestHit(
                            INPUT_PROP(_QuadraticConfig),
                            origin, direction, 
                            INPUT_PROP(_ArcRadius),
                            INPUT_PROP(_CylinderRadius)
                        );
                        if(!cylinderHitProp.isHit){
                            // 未命中覆盖为背景颜色
                            reflectionRayIntersection.color = float4(BackgroundColor(direction), 1.0f);
                            TraceRay(_AccelerationStructure, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFF, 0, 1, 0, rayDescriptor, reflectionRayIntersection);
                        }
                        else{
                            // 构建BRDF表面
                            Surface surface;
                            surface.color = INPUT_PROP(_BaseColor).rgb;
                            surface.alpha = INPUT_PROP(_BaseColor).a;                           
                            surface.metallic = INPUT_PROP(_Metallic);
                            surface.smoothness = INPUT_PROP(_Smoothness);
                            surface.position = cylinderHitProp.hitPoint;
                            surface.viewDirection = -direction;
                            surface.normal = cylinderHitProp.hitNormal;
                            BRDF brdf = GetBRDF(surface);

                            // 利用BRDF着色覆盖结果
                            reflectionRayIntersection.color = float4(RTDirectBRDF(surface, brdf), 1.0f);
                        }
                    #endif
                    #if defined(_RAY_MARCHING_COLUMN)
                        HitProperties cylinderHitProp = ColumnHit(
                            origin, direction, 
                            INPUT_PROP(_ColumnLengthWidthHeight), 
                            INPUT_PROP(_VerticalSegments),
                            INPUT_PROP(_CylinderRadius),
                            INPUT_PROP(_SecondaryCylinderRadius)
                        );
                        if(!cylinderHitProp.isHit){
                            // 未命中覆盖为背景颜色
                            reflectionRayIntersection.color = float4(BackgroundColor(direction), 1.0f);
                            TraceRay(_AccelerationStructure, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFF, 0, 1, 0, rayDescriptor, reflectionRayIntersection);
                        }
                        else{
                            // 构建BRDF表面
                            Surface surface;
                            surface.color = INPUT_PROP(_BaseColor).rgb;
                            surface.alpha = INPUT_PROP(_BaseColor).a;                           
                            surface.metallic = INPUT_PROP(_Metallic);
                            surface.smoothness = INPUT_PROP(_Smoothness);
                            surface.position = cylinderHitProp.hitPoint;
                            surface.viewDirection = -direction;
                            surface.normal = cylinderHitProp.hitNormal;
                            BRDF brdf = GetBRDF(surface);

                            // 利用BRDF着色覆盖结果
                            reflectionRayIntersection.color = float4(RTDirectBRDF(surface, brdf), 1.0f);
                        }
                    #endif
                    #if defined(_RAY_MARCHING_QUADRA)
                        HitProperties cylinderHitProp = PhantomTestHit(
                            INPUT_PROP(_QuadraticConfig),
                            origin, direction, 
                            1.0f,
                            INPUT_PROP(_CylinderRadius)
                        );
                        if(!cylinderHitProp.isHit){
                            // 未命中覆盖为背景颜色
                            reflectionRayIntersection.color = float4(BackgroundColor(direction), 1.0f);
                            TraceRay(_AccelerationStructure, RAY_FLAG_CULL_BACK_FACING_TRIANGLES, 0xFF, 0, 1, 0, rayDescriptor, reflectionRayIntersection);
                        }
                        else{
                            // 构建BRDF表面
                            Surface surface;
                            surface.color = INPUT_PROP(_BaseColor).rgb;
                            surface.alpha = INPUT_PROP(_BaseColor).a;                           
                            surface.metallic = INPUT_PROP(_Metallic);
                            surface.smoothness = INPUT_PROP(_Smoothness);
                            surface.position = cylinderHitProp.hitPoint;
                            surface.viewDirection = -direction;
                            surface.normal = cylinderHitProp.hitNormal;
                            BRDF brdf = GetBRDF(surface);

                            // 利用BRDF着色覆盖结果
                            reflectionRayIntersection.color = float4(RTDirectBRDF(surface, brdf), 1.0f);
                        }
                    #endif

                    color = reflectionRayIntersection.color;
                }

                // 最终的颜色
                rayIntersection.color = color;
            }

            ENDHLSL
        }
    }

    // 指示Unity使用CustomShaderGUI类的实例来绘制Lit着色器的检查器
    CustomEditor "CustomShaderGUI" 
}
