using System;
using UnityEngine.Rendering;

[Serializable]
public class CameraSettings
{
    // 渲染层掩码，-1表示所有层
    [RenderingLayerMaskField]
    public int renderingLayerMask = -1;

    // 将遮罩转换为灯光遮罩
    public bool maskLights = false;

    public bool overridePostFX = false;

    public PostFXSettings postFXSettings = default;

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
}