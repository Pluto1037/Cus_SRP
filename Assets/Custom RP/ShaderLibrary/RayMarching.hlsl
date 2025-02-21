#ifndef CUS_RAY_MARCHING_INCLUDED
#define CUS_RAY_MARCHING_INCLUDED

#pragma enable_d3d11_debug_symbols

struct HitProperties {
    bool isHit;
    float3 hitPoint;
    float3 hitNormal;
};

// 定义球体SDF，半径为1
float SdfSphere(float3 p) {
    return length(p) - 1;
}
// 获取当前行进点与物体中心的距离
float RMGetDist(float3 p) {
    float sdf = SdfSphere(p);
    return sdf;
} 
//计算法线
float3 RMGetNormal(float3 position)
{
    return normalize(position);
}

// 圆柱的SDF，定义从（0，1，0）到（0，-1，0）的半径为1的圆柱
// 返回与中轴线的距离
float RMGetCylinderDist(float3 rayOrigin, float3 rayDirection, float3 start, float3 end, float radius)
{
    float3 centerLineDir = end - start;
    float3 centerLinePos = start;

    float3 p = rayOrigin - centerLinePos; // 直线两定点的向量，用作距离投影
    // 利用空间中异面直线距离公式计算
    float3 n = cross(rayDirection, centerLineDir); // 两直线的法向量
    float ln = length(n);
    float dist;
    if (ln == 0) {
        dist = length(cross(p, centerLineDir)) / length(centerLineDir); // 射线距离中轴线的距离
    }
    else dist = abs(dot(n, p)) / ln; // 射线距离中轴线的距离

    return dist;
}
// 根据两条射线求得最短距离的坐标的参数
// 返回的第一个参数为圆柱中轴线上的参数t，第二个参数为光线上的参数s
float2 calcTwoLineCrossVec(float3 cylinderStart, float3 cylinderDir,float3 rayOrigin, float3 rayDirection)
{
    float3 p = cylinderStart - rayOrigin;
    float cylDotRay = dot(rayDirection, cylinderDir);
    float D = cylDotRay * cylDotRay - 1;

    float t = (dot(cylinderDir, p) - cylDotRay * dot(rayDirection, p)) / D;
    float s = (cylDotRay * dot(cylinderDir, p) - dot(rayDirection, p)) / D;

    return float2(t, s);
}
// 判断是否击中圆柱两端
HitProperties HitCircle(float cylDotRay, float3 rayOrigin, float3 rayDirection, 
    float3 startVec, float3 endVec, float3 planeNormal, float radius)
{
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);
    if (cylDotRay == 0.0) { // 90°不会击中侧面       
        return hitProp;
    }
    // 计算射线与端点在截面上的交点
    float t = 0; // 根据射线参数方程求交点
    float3 hitPoint;
    // 平面与射线求交
    if (cylDotRay > 0) {
        t = dot(planeNormal, startVec - rayOrigin) / cylDotRay;    
        hitPoint = rayOrigin + rayDirection * t;
        if (length(hitPoint - startVec) < radius) {
            hitProp.isHit = true;
            hitProp.hitPoint = hitPoint;
            hitProp.hitNormal = -planeNormal;
            return hitProp;
        }
    }
    else {
        t = dot(planeNormal, endVec - rayOrigin) / cylDotRay;    
        hitPoint = rayOrigin + rayDirection * t;
        if (length(hitPoint - endVec) < radius) {
            hitProp.isHit = true;
            hitProp.hitPoint = hitPoint;
            hitProp.hitNormal = planeNormal;
            return hitProp;
        }
    }

    return hitProp; // 默认未击中
    
}
// 判断是否击中圆柱的侧面
bool isHitSide(float sideDist, float startCrossDist, float endCrossDist, bool isSameDir, float height)
{
    float maxCrossDist = max(startCrossDist, endCrossDist);
    // 交点在外：判断唯一交点的位置
    if (maxCrossDist >= height) {
        if (isSameDir && (sideDist < endCrossDist || sideDist > startCrossDist)) return false;
        if (!isSameDir && (sideDist < startCrossDist || sideDist > endCrossDist)) return false;
    }
    // 交点在内：根据方向选择两个交点之一，判断射线是否击中圆柱侧面
    else {
        if(isSameDir && startCrossDist < sideDist) return false;
        if(!isSameDir && endCrossDist < sideDist) return false;
    }

    return true;
}
// 根据最短距离点的坐标，计算击中侧面的坐标，在最短距离横截面上
float3 SideHitVecOnCross(float3 rayOrigin, float3 rayDirection, float3 cylinderDir, float crossProp, float halfCrossLen)
{
    // 计算rayDirection在截面上的投影
    float3 rayDirOnPlane = normalize(rayDirection - dot(rayDirection, cylinderDir) * cylinderDir);
    float3 hitPoint = rayOrigin + crossProp * rayDirection - halfCrossLen * rayDirOnPlane;
    return hitPoint;
}


// 光线步进
// disList.x = MAX_STEP, disList.y = SURF_DIST, disList.z = MAX_DIST
float RayMarch(float3 rayOrigin, float3 rayDirection, float3 disList )
{
    float disFromOrigion = 0; // 终点距离射线起点的距离
    float disFromSphere; // 距离物体的距离
    for (int i = 0; i < disList.x; i++)
    {
        float3 position = rayOrigin + rayDirection * disFromOrigion; // 射线目前的终点坐标
        disFromSphere = RMGetDist(position); // 该点离物体的距离
        disFromOrigion += disFromSphere; // 用计算出来的离物体的距离更新终点
        if(disFromSphere < disList.y || disFromOrigion > disList.z) break; // 如果该点离物体的距离非常小或者该点到起点的距离超过了最大值，就不继续前进了
    }
    return disFromOrigion; // 返回击中物体的点到起点的距离或者返回一个超过最大距离的值-表明没击中物体
}
// 光线求交，返回法向量
HitProperties CylinderHit(float3 rayOrigin, float3 rayDirection, 
    float3 cylinderStart, float3 cylinderEnd, float cylinderRadius)
{
    // 圆柱信息定义
    // float3 cylinderStart = float3(0, 1, 0);
    // float3 cylinderEnd = float3(0, -1, 0);
    // float cylinderRadius = 1;

    // 初步判断    
    float3 cylinderDir = normalize(cylinderEnd - cylinderStart);  
    float cylDotRay = dot(rayDirection, cylinderDir);
    bool isSameDir = cylDotRay > 0;
    float height = length(cylinderEnd - cylinderStart);

    // 默认未击中返回
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    // 求射线与圆柱中轴线的最短距离，快速筛选需要进一步求交的射线
    float cylinderLineDist = RMGetCylinderDist(rayOrigin, rayDirection, cylinderStart, cylinderEnd, cylinderRadius);
    if (cylinderLineDist > cylinderRadius) return hitProp;

    float halfCrossLen = sqrt(cylinderRadius * cylinderRadius - cylinderLineDist * cylinderLineDist);
    // 计算两射线最短距离坐标
    float2 crossProp = calcTwoLineCrossVec(cylinderStart, cylinderDir, rayOrigin, rayDirection);   

    // 根据夹角与方向快速判断是否击中圆柱截面
    HitProperties circleHitProp = HitCircle(cylDotRay, rayOrigin, rayDirection, 
        cylinderStart, cylinderEnd, cylinderDir, cylinderRadius);
    if (circleHitProp.isHit) return circleHitProp;
    
    // 根据theta求得射线在圆柱中轴线方向的偏移距离
    float theta = acos(abs(cylDotRay));
    float sideDist = halfCrossLen * cos(theta) / sin(theta);
    // 获取交点距离起点和终点的距离
    float startCrossDist = abs(crossProp.x);
    float endCrossDist = abs(height - crossProp.x);    
    // 判断是否击中圆柱侧面
    bool sideHit = isHitSide(sideDist, startCrossDist, endCrossDist, isSameDir, height);

    if (sideHit) { 
        // 计算侧面击中信息
        float3 sideHitVecCross = SideHitVecOnCross(rayOrigin, rayDirection, cylinderDir, crossProp.y, halfCrossLen);
        hitProp.isHit = true;
        hitProp.hitNormal = normalize(sideHitVecCross - (cylinderStart + crossProp.x * cylinderDir));
        hitProp.hitPoint = isSameDir ? ( sideHitVecCross - sideDist * cylinderDir)
            : (sideHitVecCross + sideDist * cylinderDir);

        return hitProp;      
    }

    return hitProp;
}
// 根据单根圆柱交点计算函数，计算命中矩阵的交点信息
// Grid的中心默认在物体的0,0,0
HitProperties GridHit(float3 rayOrigin, float3 rayDirection,
    float2 gridSize, float2 gridSeg, float cylinderRadius, float3 gridCenter)
{
    // 根据单根求交结果，计算整个Grid的交点信息
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    // 放置的起点与间隔
    float xStart = -gridSize.x * 0.5;
    float yStart = -gridSize.y * 0.5;
    float xSize = gridSeg.x > 1 ? gridSize.x / (gridSeg.x - 1) : 0;
    float ySize = gridSeg.y > 1 ? gridSize.y / (gridSeg.y - 1) : 0;

    float minHitDist = FLT_MAX;
    float tempDist = 0;
    float3 cylinderStart, cylinderEnd;

    int i;

    // x方向遍历
    for (i = 0; i < int(gridSeg.x); i++)
    {
        cylinderStart = gridCenter + float3(xStart + i * xSize, cylinderRadius, yStart);
        cylinderEnd = gridCenter + float3(xStart + i * xSize, cylinderRadius, -yStart);
        HitProperties hit = CylinderHit(rayOrigin, rayDirection, 
            cylinderStart, cylinderEnd, cylinderRadius);
        if (hit.isHit) {
            tempDist = length(hit.hitPoint - rayOrigin);
            if (tempDist < minHitDist) {
                minHitDist = tempDist;
                hitProp = hit;
            }
        }
    }
    // y方向遍历，紧贴x方向下层
    for (i = 0; i < int(gridSeg.y); i++)
    {
        cylinderStart = gridCenter + float3(xStart, -cylinderRadius, yStart + i * ySize);
        cylinderEnd = gridCenter + float3(-xStart, -cylinderRadius, yStart + i * ySize);
        HitProperties hit = CylinderHit(rayOrigin, rayDirection, 
            cylinderStart, cylinderEnd, cylinderRadius);
        if (hit.isHit) {
            tempDist = length(hit.hitPoint - rayOrigin);
            if (tempDist < minHitDist) {
                minHitDist = tempDist;
                hitProp = hit;
            }
        }
    }

    return hitProp;
}

#endif