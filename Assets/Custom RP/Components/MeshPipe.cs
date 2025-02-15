using UnityEngine;
using UnityEngine.Rendering;

public class MeshPipe : MonoBehaviour
{
    static int rowNum = 100;
    static int instancedNumber = rowNum * rowNum;

    [SerializeField]
    Mesh mesh = default;

    [SerializeField]
    Material material = default;

    [SerializeField]
    LightProbeProxyVolume lightProbeVolume = null;

    // 通过填充变换矩阵和颜色的数组，可以实例化1023个球体
    Matrix4x4[] matrices = new Matrix4x4[instancedNumber];
    // Vector4[] baseColors = new Vector4[1023];
    // float[]
    //     metallic = new float[1023],
    //     smoothness = new float[1023];

    MaterialPropertyBlock block;

    void Awake()
    {
        Vector3 scale = new Vector3(1, 20, 1);
        Vector3 offset = new Vector3(0, 10, 0);
        float dist = 0.5f;
        for (int i = 0; i < matrices.Length; i++)
        {
            offset.x = dist * i % rowNum * 2;
            offset.z = dist * i / rowNum * 2;
            matrices[i] = Matrix4x4.TRS(
                transform.position + offset,
                Quaternion.Euler(0, 0, 0),
                scale
            );
            // baseColors[i] =
            //     new Vector4(
            //         Random.value, Random.value, Random.value,
            //         Random.Range(0.5f, 1f) // 随机透明度
            //     );
            // metallic[i] = Random.value < 0.25f ? 1f : 0f;
            // smoothness[i] = Random.Range(0.05f, 0.95f);
        }
    }

    void Update()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
            // block.SetVectorArray(baseColorId, baseColors);
            // block.SetFloatArray(metallicId, metallic);
            // block.SetFloatArray(smoothnessId, smoothness);
            if (!lightProbeVolume)
            {
                // 存储实例位置，用于光照探针插值
                var positions = new Vector3[instancedNumber];
                for (int i = 0; i < matrices.Length; i++)
                {
                    positions[i] = matrices[i].GetColumn(3);
                }
                var lightProbes = new SphericalHarmonicsL2[instancedNumber];
                var occlusionProbes = new Vector4[instancedNumber];
                LightProbes.CalculateInterpolatedLightAndOcclusionProbes(
                    positions, lightProbes, occlusionProbes
                );
                block.CopySHCoefficientArraysFrom(lightProbes); // 复制光照探针系数
                block.CopyProbeOcclusionArrayFrom(occlusionProbes); // 复制遮挡探针
            }
        }
        // 实例化绘制
        Graphics.DrawMeshInstanced(
            mesh, 0, material, matrices, instancedNumber, block,
            ShadowCastingMode.On, true, 0, null,
            lightProbeVolume ?
                LightProbeUsage.UseProxyVolume : LightProbeUsage.CustomProvided,
            lightProbeVolume
        );
    }
}