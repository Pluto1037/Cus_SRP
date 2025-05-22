using System;
using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Rendering;

public class QuadraticHelper
{
    // 全局定义的参数 A、B、C，假设在类中声明：
    public float A = 2.8f;
    public float B = 1.09f;
    public float C = -1.29f;

    public float arcRadius = 1.0f; // 区间缩放因子

    /// <summary>
    /// 计算二次函数在射线局部坐标中的参数s
    /// </summary>
    public Vector3 T2QuadraticFuncPointLocal(float t)
    {
        float x = t * arcRadius;
        Vector3 localPoint = new Vector3(x, 0, A * x * x + B * x + C);
        return localPoint;
    }

    public Vector3 T2QuadraticFuncTangentLocal(float t)
    {
        float x = t * arcRadius;
        Vector3 localTangent = new Vector3(1.0f, 0, 2 * A * x + B);
        return localTangent;
    }

    public static bool IntersectCylinder(
        Vector3 O, Vector3 D,
        Vector3 A, Vector3 B, float r,
        out float t, out Vector3 P, out Vector3 normal, out float dt)
    {
        Vector3 C = B - A;
        float lenC_sq = Vector3.Dot(C, C);

        float lenC = (float)Math.Sqrt(lenC_sq);
        Vector3 C_dir = C / lenC;
        Vector3 OA = O - A;

        // Side intersection test
        Vector3 cross_OA_C = Vector3.Cross(OA, C);
        Vector3 cross_D_C = Vector3.Cross(D, C);

        float a = Vector3.Dot(cross_D_C, cross_D_C);
        float b = 2 * Vector3.Dot(cross_OA_C, cross_D_C);
        float c = Vector3.Dot(cross_OA_C, cross_OA_C) - r * r * lenC_sq;

        float delta = b * b - 4 * a * c;
        float t_proj = 0;

        t = 0;
        P = Vector3.zero;
        normal = Vector3.zero;

        delta = Math.Max(delta, 0.0f);

        float sqrt_delta = MathF.Sqrt(delta);
        float s0 = (-b - sqrt_delta) / (2 * a);
        float s1 = (-b + sqrt_delta) / (2 * a);

        float s = s0;
        if (Math.Abs(s1) < Math.Abs(s0))
        {
            s = s1;
        }
        else
        {
            s = s0;
        }
        s = Math.Max(s, 0.0f);

        Vector3 P_side = O + s * D;
        float proj = Vector3.Dot(P_side - A, C);
        dt = proj / lenC_sq;

        t = s;
        P = O + t * D;
        Vector3 axisPoint = A + t_proj * C;
        normal = Vector3.Normalize(P - axisPoint);

        return true;
    }



}