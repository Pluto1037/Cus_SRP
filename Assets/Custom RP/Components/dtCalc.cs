using System.Collections;
using System.Collections.Generic;
using System.Net;
using Unity.VisualScripting;
using UnityEngine;
using XCharts.Runtime;

//[ExecuteInEditMode]
public class dtCalc : MonoBehaviour
{
    public GameObject target; //扫掠体所在物体

    public LineChart lineChart; //折线图

    [Range(0, 1)]
    public float t = 0; //扫掠体所在物体的位置参数
    [Range(0, 10000)]
    public int iterNum = 10000;
    Ray ray;  //声明射线
    Ray tangentRay; //声明切线射线

    float maxDt = 0; //最大交点参数值
    public GameObject Point;

    QuadraticHelper qh; //二次函数参数类

    float[] values = new float[100000]; //存储交点的参数值
    float[] vcValues = new float[100000]; //存储交点的参数值
    Vector3[] points = new Vector3[100000]; //存储交点的世界坐标
    void Start()
    {
        ray = new Ray();
        qh = new QuadraticHelper(); //实例化二次函数参数类
    }

    // Update is called once per frame
    void Update()
    {
        if (Input.GetKeyDown(KeyCode.O))
        {
            //从摄像机发出射线的点
            ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            float maxT = 0f;
            if (Physics.Raycast(ray, out hit))
            {
                ray.direction = hit.point - ray.origin; //计算射线方向
                for (int i = 0; i < iterNum; i++)
                {
                    float t = (float)i / iterNum;
                    Vector3 worldPoint = target.transform.rotation * qh.T2QuadraticFuncPointLocal(t) + target.transform.position; //计算世界坐标
                    Vector3 worldTangent = target.transform.rotation * qh.T2QuadraticFuncTangentLocal(t); //计算世界切线
                    worldTangent.Normalize(); //归一化切线

                    Vector3 normal, P;
                    float s, dt;

                    if (QuadraticHelper.IntersectCylinder(ray.origin, ray.direction, worldPoint, worldPoint + worldTangent, 0.07f, out s, out P, out normal, out dt))
                    {
                        values[i] = dt;
                        points[i] = P;
                        if (dt > maxDt)
                        {
                            maxT = t;
                            maxDt = dt;
                        }
                    } //计算交点

                    float dot = Vector3.Dot(ray.origin, worldTangent);
                    float ddt = Vector3.Dot(ray.direction, worldTangent);
                    float dwt = Vector3.Dot(worldPoint, worldTangent);
                    float t_rayplane = (dwt - dot) / ddt;
                    Vector3 p = ray.origin + ray.direction * t_rayplane - worldPoint;
                    vcValues[i] = Mathf.Sqrt(Vector3.Dot(p, p)) - 0.07f;
                }

                if (lineChart != null)
                {
                    var xAxis = lineChart.EnsureChartComponent<XAxis>();
                    var yAxis = lineChart.EnsureChartComponent<YAxis>();
                    xAxis.splitNumber = 10;
                    xAxis.min = 0;
                    xAxis.max = 1;
                    xAxis.type = Axis.AxisType.Value;
                    yAxis.type = Axis.AxisType.Value;

                    lineChart.RemoveData();
                    lineChart.AddSerie<Line>("line");
                    lineChart.AddSerie<Line>("line2");
                    for (int i = 0; i < iterNum; i++)
                    {
                        lineChart.AddData(0, i / (float)iterNum, values[i]);
                        lineChart.AddData(1, i / (float)iterNum, vcValues[i]);
                    }
                }
                Vector3 localPoint = qh.T2QuadraticFuncPointLocal(maxT);
                Vector3 localTangent = qh.T2QuadraticFuncTangentLocal(maxT); //计算局部切线
                if (target != null)
                {
                    Vector3 worldPoint = target.transform.rotation * localPoint + target.transform.position;
                    Vector3 worldTangent = target.transform.rotation * localTangent;
                    tangentRay.origin = worldPoint;
                    tangentRay.direction = worldTangent;
                }
            }
        }
        Debug.DrawRay(ray.origin, ray.direction * 100, Color.red, 2f); //绘制射线


        Debug.DrawRay(tangentRay.origin, tangentRay.direction * 1000, Color.green, 2f); //绘制切线射线
        Debug.DrawRay(tangentRay.origin, -tangentRay.direction * 1000, Color.green, 2f); //绘制切线射线

        Point.transform.position = points[(int)(t * iterNum)];
    }



}
