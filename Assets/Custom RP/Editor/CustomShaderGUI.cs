using System.Linq;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

public class CustomShaderGUI : ShaderGUI
{

    MaterialEditor editor; // 材质编辑器
    Object[] materials; // 材质数组
    MaterialProperty[] properties; // 材质属性数组
    enum ShadowMode
    {
        On, Clip, Dither, Off
    }

    bool showPresets;

    bool showRT;
    Vector3 cylStart;
    Vector3 cylEnd;
    float cylRadius;

    string[] options = new string[] { "Single", "Grid" };

    // 网格状分布参数
    int cylSelected;
    float gridWidth;
    float gridHeight;
    int widthSegments;
    int heightSegments;

    public override void OnGUI(
        MaterialEditor materialEditor, MaterialProperty[] properties
    )
    {
        editor = materialEditor;
        materials = materialEditor.targets;
        this.properties = properties;

        // 获取属性的原值
        Material targetMat = materialEditor.target as Material;
        string[] keyWords = targetMat.shaderKeywords;
        if (keyWords.Contains("_RAY_MARCHING"))
        {
            cylSelected = 0;
            showRT = true;
        }
        else if (keyWords.Contains("_RAY_MARCHING_GRID"))
        {
            cylSelected = 1;
            showRT = true;
        }
        else
        {
            showRT = false;
        }
        // showRT = keyWords.Contains("_RAY_MARCHING") || keyWords.Contains("_RAY_MARCHING_GRID");
        cylStart = FindProperty("_CylinderStart", properties, false).vectorValue;
        cylEnd = FindProperty("_CylinderEnd", properties, false).vectorValue;
        cylRadius = FindProperty("_CylinderRadius", properties, false).floatValue;
        Vector3 gridWH = FindProperty("_GridWidthHeight", properties, false).vectorValue;
        Vector3 gridWHSeg = FindProperty("_WidthHeightSegments", properties, false).vectorValue;
        gridWidth = gridWH.x;
        gridHeight = gridWH.y;
        widthSegments = (int)gridWHSeg.x;
        heightSegments = (int)gridWHSeg.y;

        EditorGUI.BeginChangeCheck();
        // 在顶部设置RM材质表达
        showRT = EditorGUILayout.ToggleLeft("Enable Ray Tracing Cylinder", showRT);
        if (showRT)
        {
            cylSelected = EditorGUILayout.Popup("Type", cylSelected, options);
            switch (cylSelected)
            {
                case 0:
                    cylStart = EditorGUILayout.Vector3Field("Cylinder Start", cylStart);
                    cylEnd = EditorGUILayout.Vector3Field("Cylinder End", cylEnd);
                    break;
                case 1:
                    gridWidth = Mathf.Max(0.1f, EditorGUILayout.FloatField("Grid Width", gridWidth));
                    gridHeight = Mathf.Max(0.1f, EditorGUILayout.FloatField("Grid Height", gridHeight));
                    widthSegments = Mathf.Max(1, EditorGUILayout.IntField("Width Segments", widthSegments));
                    heightSegments = Mathf.Max(1, EditorGUILayout.IntField("Height Segments", heightSegments));
                    break;
                default:
                    Debug.LogError("Unrecognized Option");
                    break;
            }
            cylRadius = Mathf.Max(0, EditorGUILayout.FloatField("Cylinder Radius", cylRadius));
        }
        EditorGUILayout.Space();

        // 按顺序排布UI元素
        base.OnGUI(materialEditor, properties);

        BakedEmission();

        EditorGUILayout.Space();
        showPresets = EditorGUILayout.Foldout(showPresets, "Presets", true);
        if (showPresets)
        {
            OpaquePreset();
            ClipPreset();
            FadePreset();
            TransparentPreset();
        }
        if (EditorGUI.EndChangeCheck())
        {
            SetShadowCasterPass();
            CopyLightMappingProperties();
            SetCylinderRayTracing();
        }
    }

    void SetCylinderRayTracing()
    {
        SetProperty("_RayMarching", "_RAY_MARCHING", showRT && cylSelected == 0);
        SetProperty("_RayMarchingGrid", "_RAY_MARCHING_GRID", showRT && cylSelected == 1);
        MaterialProperty cylinderStart = FindProperty("_CylinderStart", properties, false);
        MaterialProperty cylinderEnd = FindProperty("_CylinderEnd", properties, false);
        MaterialProperty cylinderRadius = FindProperty("_CylinderRadius", properties, false);
        MaterialProperty gridWH = FindProperty("_GridWidthHeight", properties, false);
        MaterialProperty gridWHSeg = FindProperty("_WidthHeightSegments", properties, false);
        if (cylinderStart != null)
        {
            cylinderStart.vectorValue = cylStart;
        }
        if (cylinderEnd != null)
        {
            cylinderEnd.vectorValue = cylEnd;
        }
        if (cylinderRadius != null)
        {
            cylinderRadius.floatValue = cylRadius;
        }
        if (gridWH != null)
        {
            gridWH.vectorValue = new Vector3(gridWidth, gridHeight, 0);
        }
        if (gridWHSeg != null)
        {
            gridWHSeg.vectorValue = new Vector3(widthSegments, heightSegments, 0);
        }
    }

    void CopyLightMappingProperties()
    {
        MaterialProperty mainTex = FindProperty("_MainTex", properties, false);
        MaterialProperty baseMap = FindProperty("_BaseMap", properties, false);
        if (mainTex != null && baseMap != null)
        {
            mainTex.textureValue = baseMap.textureValue;
            mainTex.textureScaleAndOffset = baseMap.textureScaleAndOffset;
        }
        MaterialProperty color = FindProperty("_Color", properties, false);
        MaterialProperty baseColor =
            FindProperty("_BaseColor", properties, false);
        if (color != null && baseColor != null)
        {
            color.colorValue = baseColor.colorValue;
        }
    }

    void BakedEmission()
    {
        EditorGUI.BeginChangeCheck();
        editor.LightmapEmissionProperty();
        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material m in editor.targets)
            {
                m.globalIlluminationFlags &=
                    ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
            }
        }
    }

    void SetShadowCasterPass()
    {
        MaterialProperty shadows = FindProperty("_Shadows", properties, false);
        if (shadows == null || shadows.hasMixedValue)
        {
            return;
        }
        bool enabled = shadows.floatValue < (float)ShadowMode.Off;
        foreach (Material m in materials)
        {
            m.SetShaderPassEnabled("ShadowCaster", enabled);
        }
    }

    bool SetProperty(string name, float value)
    {
        MaterialProperty property = FindProperty(name, properties, false);
        if (property != null)
        {
            property.floatValue = value;
            return true;
        }
        return false;
    }
    void SetKeyword(string keyword, bool enabled)
    {
        if (enabled)
        {
            foreach (Material m in materials)
            {
                m.EnableKeyword(keyword);
            }
        }
        else
        {
            foreach (Material m in materials)
            {
                m.DisableKeyword(keyword);
            }
        }
    }
    void SetProperty(string name, string keyword, bool value)
    {
        if (SetProperty(name, value ? 1f : 0f))
        {
            SetKeyword(keyword, value);
        }
    }

    bool Clipping
    {
        set => SetProperty("_Clipping", "_CLIPPING", value);
    }
    bool PremultiplyAlpha
    {
        set => SetProperty("_PremulAlpha", "_PREMULTIPLY_ALPHA", value);
    }
    BlendMode SrcBlend
    {
        set => SetProperty("_SrcBlend", (float)value);
    }
    BlendMode DstBlend
    {
        set => SetProperty("_DstBlend", (float)value);
    }
    bool ZWrite
    {
        set => SetProperty("_ZWrite", value ? 1f : 0f);
    }
    RenderQueue RenderQueue
    {
        set
        {
            foreach (Material m in materials)
            {
                m.renderQueue = (int)value;
            }
        }
    }
    ShadowMode Shadows
    {
        set
        {
            if (SetProperty("_Shadows", (float)value))
            {
                SetKeyword("_SHADOWS_CLIP", value == ShadowMode.Clip);
                SetKeyword("_SHADOWS_DITHER", value == ShadowMode.Dither);
            }
        }
    }

    bool PresetButton(string name)
    {
        if (GUILayout.Button(name))
        {
            editor.RegisterPropertyChangeUndo(name);
            return true;
        }
        return false;
    }

    void OpaquePreset()
    {
        if (PresetButton("Opaque"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.Geometry;
        }
    }
    void ClipPreset()
    {
        if (PresetButton("Clip"))
        {
            Clipping = true;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.Zero;
            ZWrite = true;
            RenderQueue = RenderQueue.AlphaTest;
        }
    }
    void FadePreset()
    {
        if (PresetButton("Fade"))
        {
            Clipping = false;
            PremultiplyAlpha = false;
            SrcBlend = BlendMode.SrcAlpha;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
        }
    }
    bool HasProperty(string name) =>
        FindProperty(name, properties, false) != null;
    bool HasPremultiplyAlpha => HasProperty("_PremulAlpha");
    void TransparentPreset()
    {
        if (HasPremultiplyAlpha && PresetButton("Transparent"))
        {
            Clipping = false;
            PremultiplyAlpha = true;
            SrcBlend = BlendMode.One;
            DstBlend = BlendMode.OneMinusSrcAlpha;
            ZWrite = false;
            RenderQueue = RenderQueue.Transparent;
        }
    }
}