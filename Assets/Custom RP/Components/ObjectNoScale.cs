using System;
using UnityEngine;

// 在CPU计算物体的非缩放矩阵
[DisallowMultipleComponent]
[ExecuteAlways]
public class ObjectNoScale : MonoBehaviour
{

    static int
        // baseColorId = Shader.PropertyToID("_BaseColor"),
        // cutoffId = Shader.PropertyToID("_Cutoff"), // 透明度裁剪值
        // metallicId = Shader.PropertyToID("_Metallic"),
        // smoothnessId = Shader.PropertyToID("_Smoothness"),
        rotationMatrixId = Shader.PropertyToID("_RotationMatrix"),
        inverseRotationMatrixId = Shader.PropertyToID("_InverseRotationMatrix"),
        worldPositionId = Shader.PropertyToID("_WorldPosition");


    // [SerializeField]
    // Color baseColor = Color.white;

    // [SerializeField, Range(0f, 1f)]
    // float cutoff = 0.5f, metallic = 0f, smoothness = 0.5f;

    static MaterialPropertyBlock block;

    void OnValidate()
    {
        if (block == null)
        {
            block = new MaterialPropertyBlock();
        }
        // block.SetColor(baseColorId, baseColor);
        // block.SetFloat(cutoffId, cutoff);
        // block.SetFloat(metallicId, metallic);
        // block.SetFloat(smoothnessId, smoothness);
        Matrix4x4 rotationMatrix = Matrix4x4.Rotate(transform.rotation);
        block.SetMatrix(rotationMatrixId, rotationMatrix);
        block.SetMatrix(inverseRotationMatrixId, rotationMatrix.transpose);
        block.SetVector(worldPositionId, transform.position);
        GetComponent<Renderer>().SetPropertyBlock(block);
    }
    void Awake()
    {
        OnValidate();
    }
    void Update()
    {
        OnValidate();
    }
}