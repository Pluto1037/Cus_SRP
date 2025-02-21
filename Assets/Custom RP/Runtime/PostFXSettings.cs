using System;
using UnityEngine;

[CreateAssetMenu(menuName = "Rendering/Custom Post FX Settings")]
public class PostFXSettings : ScriptableObject
{
    [SerializeField]
    Shader shader = default;
    [NonSerialized]
    Material material; // 利用Unity的Material作为后处理材质载体
    public Material Material
    {
        get
        {
            if (material == null && shader != null)
            {
                material = new Material(shader);
                material.hideFlags = HideFlags.HideAndDontSave;
            }
            return material;
        }
    }

    [Serializable]
    public struct BloomSettings
    {
        public bool ignoreRenderScale;

        [Range(0f, 16f)]
        public int maxIterations;

        [Min(1f)]
        public int downscaleLimit;

        public bool bicubicUpsampling; // 启用时开启双三次上采样

        [Min(0f)]
        public float threshold;

        [Range(0f, 1f)]
        public float thresholdKnee;

        [Min(0f)]
        public float intensity;
        public bool fadeFireflies; // 用于淡化开启HDR时小区域高光的频闪

        // 高光散射
        public enum Mode { Additive, Scattering }
        public Mode mode;
        [Range(0.05f, 0.95f)]
        public float scatter;
    }
    [SerializeField]
    BloomSettings bloom = new BloomSettings
    {
        scatter = 0.7f // 默认值0无效，需显式设置初值
    };
    public BloomSettings Bloom => bloom;

    [Serializable]
    public struct ColorAdjustmentsSettings
    {
        public float postExposure;

        [Range(-100f, 100f)]
        public float contrast;

        [ColorUsage(false, true)]
        public Color colorFilter;

        [Range(-180f, 180f)]
        public float hueShift;

        [Range(-100f, 100f)]
        public float saturation;
    }
    [SerializeField]
    ColorAdjustmentsSettings colorAdjustments = new ColorAdjustmentsSettings
    {
        colorFilter = Color.white
    };
    public ColorAdjustmentsSettings ColorAdjustments => colorAdjustments;

    [Serializable]
    public struct WhiteBalanceSettings
    {
        [Range(-100f, 100f)]
        public float temperature, tint;
    }
    [SerializeField]
    WhiteBalanceSettings whiteBalance = default;
    public WhiteBalanceSettings WhiteBalance => whiteBalance;

    [Serializable]
    public struct SplitToningSettings
    {
        [ColorUsage(false)]
        public Color shadows, highlights;

        [Range(-100f, 100f)]
        public float balance;
    }
    [SerializeField]
    SplitToningSettings splitToning = new SplitToningSettings
    {
        shadows = Color.gray,
        highlights = Color.gray
    };
    public SplitToningSettings SplitToning => splitToning;

    [Serializable]
    public struct ChannelMixerSettings
    {
        public Vector3 red, green, blue;
    }
    [SerializeField]
    ChannelMixerSettings channelMixer = new ChannelMixerSettings
    {
        red = Vector3.right,
        green = Vector3.up,
        blue = Vector3.forward
    };
    public ChannelMixerSettings ChannelMixer => channelMixer;

    [Serializable]
    public struct ShadowsMidtonesHighlightsSettings
    {
        [ColorUsage(false, true)]
        public Color shadows, midtones, highlights;

        [Range(0f, 2f)]
        public float shadowsStart, shadowsEnd, highlightsStart, highLightsEnd;
    }
    [SerializeField]
    ShadowsMidtonesHighlightsSettings
        shadowsMidtonesHighlights = new ShadowsMidtonesHighlightsSettings
        {
            shadows = Color.white,
            midtones = Color.white,
            highlights = Color.white,
            shadowsEnd = 0.3f,
            highlightsStart = 0.55f,
            highLightsEnd = 1f
        };
    public ShadowsMidtonesHighlightsSettings ShadowsMidtonesHighlights =>
        shadowsMidtonesHighlights;

    [Serializable]
    public struct ToneMappingSettings
    {
        // 缺省为0，后面递增，按照字母顺序设置pass
        public enum Mode { None, ACES, Neutral, Reinhard }

        public Mode mode;
    }
    [SerializeField]
    ToneMappingSettings toneMapping = default;
    public ToneMappingSettings ToneMapping => toneMapping;
}