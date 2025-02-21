using System;
using UnityEngine;
using UnityEngine.Rendering;

[Serializable]
public class CameraSettings
{
    // 是否开启深度复制
    public bool copyColor = true, copyDepth = true;

    // 渲染层掩码，-1表示所有层
    [RenderingLayerMaskField]
    public int renderingLayerMask = -1;

    // 将遮罩转换为灯光遮罩
    public bool maskLights = false;

    public enum RenderScaleMode { Inherit, Multiply, Override }

    public RenderScaleMode renderScaleMode = RenderScaleMode.Inherit;

    [Range(CameraRenderer.renderScaleMin, CameraRenderer.renderScaleMax)]
    public float renderScale = 1f;

    public bool overridePostFX = false;

    public PostFXSettings postFXSettings = default;

    public bool allowFXAA = false;

    // 与Fxaa使用了透明度通道有关，多透明相机叠加时需启用，Luma会更暗
    public bool keepAlpha = false;

    [Serializable]
    public struct FinalBlendMode
    {

        public BlendMode source, destination;
    }

    public FinalBlendMode finalBlendMode = new FinalBlendMode
    {
        source = BlendMode.One,
        destination = BlendMode.Zero
    };

    public float GetRenderScale(float scale)
    {
        return
            renderScaleMode == RenderScaleMode.Inherit ? scale :
            renderScaleMode == RenderScaleMode.Override ? renderScale :
            scale * renderScale;
    }
}