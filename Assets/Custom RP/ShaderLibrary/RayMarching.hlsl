#ifndef CUS_RAY_MARCHING_INCLUDED
#define CUS_RAY_MARCHING_INCLUDED

#pragma enable_d3d11_debug_symbols

struct HitProperties {
    bool isHit;
    float3 hitPoint;
    float3 hitNormal;
    float3 testColor;
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
// 判断是否击中圆柱两端的圆球
HitProperties HitSphere(float3 rayOrigin, float3 rayDirection, 
    float3 startVec, float3 planeNormal, float radius)
{
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    float3 sphereCenter = startVec;
    float3 sn = -planeNormal;
    // 计算光线起点到球心的向量
    float3 oc = rayOrigin - sphereCenter;

    // 构建二次方程系数
    float a = dot(rayDirection, rayDirection); // 由于已归一化，a=1
    float b = 2.0 * dot(rayDirection, oc);
    float c = dot(oc, oc) - radius * radius;

    // 计算判别式
    float discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return hitProp; // 无实根，直接返回

    // 计算根
    float sqrtD = sqrt(discriminant);
    float t1 = (-b - sqrtD) / (2 * a);
    float t2 = (-b + sqrtD) / (2 * a);

    // 确保 t1 <= t2
    if (t1 > t2) {
        float temp = t1;
        t1 = t2;
        t2 = temp;
    }

    // 遍历候选根，寻找有效交点
    float t = -1.0;
    for (int i = 0; i < 2; ++i) {
        float candidateT = (i == 0) ? t1 : t2;
        if (candidateT < 0) continue; // 忽略负值

        // 计算交点位置
        float3 P = rayOrigin + candidateT * rayDirection;
        float3 P_sphere = P - sphereCenter;

        // 检查条件 1：交点在半球开口方向
        bool inHemisphere = dot(P_sphere, sn) >= 0;

        // 检查条件 2：光线击中外表面（入射方向与法线相反）
        bool isFrontFace = dot(rayDirection, P_sphere) < 0;

        if (inHemisphere && isFrontFace) {
            t = candidateT;
            break; // 优先选择较小的 t
        }
    }

    // 填充命中结果
    if (t >= 0) {
        hitProp.isHit = true;
        hitProp.hitPoint = rayOrigin + t * rayDirection;
        hitProp.hitNormal = normalize(hitProp.hitPoint - sphereCenter);
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
// 两端为球体的圆柱
HitProperties CylinderHitSphere(float3 rayOrigin, float3 rayDirection, 
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
    HitProperties sphereStartHit = HitSphere(rayOrigin, rayDirection, 
        cylinderStart, cylinderDir, cylinderRadius);
    HitProperties sphereEndHit = HitSphere(rayOrigin, rayDirection, 
        cylinderEnd, -cylinderDir, cylinderRadius);
    if (sphereStartHit.isHit && sphereEndHit.isHit) {
        if (length(sphereStartHit.hitPoint - rayOrigin) < length(sphereEndHit.hitPoint - rayOrigin)) {
            return sphereStartHit;
        }
        else return sphereEndHit;
    }
    else if (sphereStartHit.isHit) return sphereStartHit;
    else if (sphereEndHit.isHit) return sphereEndHit;
    
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

// 从CPU读取的预计算矩阵
float4x4 _RotationMatrix;
float4x4 _InverseRotationMatrix;
float4 _WorldPosition;
// 无缩放的Model变换
float3 ObjectToWorldNoScale(float3 pos)
{
    return mul((float3x3)_RotationMatrix, pos)  + _WorldPosition.xyz;
}
float3 ObjectToWorldNoScaleDir(float3 dir)
{
    return mul((float3x3)_RotationMatrix, dir);
}
float3 WorldToObjectNoScale(float3 pos)
{
    float3 translated = pos - _WorldPosition.xyz;
    return mul((float3x3)_InverseRotationMatrix, translated);
}
float3 WorldToObjectNoScaleDir(float3 dir)
{
    return mul((float3x3)_InverseRotationMatrix, dir);
}
void ProjLineIntersectWithBorder(
    float2 originProj, 
    float dirSlope,
    float2 gridSize,
    float intervalSize,
    out float grazeIStart,
    out float grazeIEnd
    )
{
    float bottom = originProj.x + (-gridSize.y * 0.5f - originProj.y) * dirSlope + gridSize.x * 0.5f;
    float top = originProj.x + (gridSize.y * 0.5f - originProj.y) * dirSlope + gridSize.x * 0.5f;
    float minEndian = clamp(min(bottom, top), 0, gridSize.x);
    float maxEndian = clamp(max(bottom, top), 0, gridSize.x);
    grazeIStart = int(minEndian / intervalSize); 
    grazeIEnd = int(maxEndian / intervalSize);
}
// 根据单根圆柱交点计算函数，计算命中矩阵的交点信息
// Grid的中心默认在物体的0,0,0
HitProperties GridHit(float3 rayOrigin, float3 rayDirection,
    float2 gridSize, float2 gridSeg, float cylinderRadius)
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

    float3 mRayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    float3 mRayOrigin = WorldToObjectNoScale(rayOrigin);
    float3 mRayOriginProjX = float3(mRayOrigin.x, cylinderRadius, mRayOrigin.z);
    float3 mRayDirectionProjX = float3(mRayDirection.x, 0.0f, mRayDirection.z);
    float3 hitPoint;
    float t = (float3(0, cylinderRadius, 0) - mRayOrigin.y) / mRayDirection.y;
    hitPoint.x = (mRayOrigin + t * mRayDirection).x;
    hitPoint.x = hitPoint.x + gridSize.x * 0.5;    
    t = (float3(0, -cylinderRadius, 0) - mRayOrigin.y) / mRayDirection.y;
    hitPoint.z = (mRayOrigin + t * mRayDirection).z;
    hitPoint.z = hitPoint.z + gridSize.y * 0.5;
    int iStart = int(hitPoint.x / xSize);
    int iEnd = iStart;  
    float grazeIStart, grazeIEnd;
    ProjLineIntersectWithBorder(
        mRayOriginProjX.xz, 
        mRayDirectionProjX.x / mRayDirectionProjX.z,
        gridSize.xy,
        xSize,
        grazeIStart,
        grazeIEnd
    );
    if (abs(mRayDirection.y) < 0.2f)
    {
        iStart = grazeIStart;
        iEnd = grazeIEnd;
    }

    int i;

    // x方向遍历
    // for (i = 0; i < int(gridSeg.x); i++)
    for (i = max(0, iStart - 1); i <= min(int(gridSeg.x - 1), iEnd + 1); i++)
    {
        cylinderStart = ObjectToWorldNoScale(
            float3(xStart + i * xSize, cylinderRadius, yStart)
        );
        cylinderEnd = ObjectToWorldNoScale(
            float3(xStart + i * xSize, cylinderRadius, -yStart)
        );
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
    int jStart = int(hitPoint.z / ySize);
    int jEnd = jStart;

    float grazeJStart, grazeJEnd;
    ProjLineIntersectWithBorder(
        mRayOriginProjX.zx, 
        mRayDirectionProjX.z / mRayDirectionProjX.x,
        gridSize.yx,
        ySize,
        grazeJStart,
        grazeJEnd
    );
    if (abs(mRayDirection.y) < 0.2f)
    {
        jStart = grazeJStart;
        jEnd = grazeJEnd;
    }

    // y方向遍历，紧贴x方向下层
    // for (i = 0; i < int(gridSeg.y); i++)
    for (i = max(0, jStart - 1); i <= min(int(gridSeg.y - 1), jEnd + 1); i++)
    {
        cylinderStart = ObjectToWorldNoScale(
            float3(xStart, -cylinderRadius, yStart + i * ySize)
        );
        cylinderEnd = ObjectToWorldNoScale(
            float3(-xStart, -cylinderRadius, yStart + i * ySize)
        );
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
HitProperties ParalHit(float3 rayOrigin, float3 rayDirection,
    float2 gridSize, float2 gridSeg, float cylinderRadius)
{
    // 根据单根求交结果，计算整个Grid的交点信息
    // 从Grid删减为Paral，默认gridSeg.y == 1
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    // 放置的起点与间隔
    float xStart = -gridSize.x * 0.5;
    float yStart = -gridSize.y * 0.5;
    float xSize = gridSeg.x > 1 ? gridSize.x / (gridSeg.x - 1) : 0;
    float ySize = 0;

    float minHitDist = FLT_MAX;
    float tempDist = 0;
    float3 cylinderStart, cylinderEnd;

    float3 mRayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    float3 mRayOrigin = WorldToObjectNoScale(rayOrigin);
    float3 mRayOriginProjX = float3(mRayOrigin.x, cylinderRadius, mRayOrigin.z);
    float3 mRayDirectionProjX = float3(mRayDirection.x, 0.0f, mRayDirection.z);
    float3 hitPoint;
    float t = (float3(0, cylinderRadius, 0) - mRayOrigin.y) / mRayDirection.y;
    hitPoint.x = (mRayOrigin + t * mRayDirection).x;
    hitPoint.x = hitPoint.x + gridSize.x * 0.5;    
    t = (float3(0, -cylinderRadius, 0) - mRayOrigin.y) / mRayDirection.y;
    hitPoint.z = (mRayOrigin + t * mRayDirection).z;
    hitPoint.z = hitPoint.z + gridSize.y * 0.5;
    int iStart = int(hitPoint.x / xSize);
    int iEnd = iStart;  
    float grazeIStart, grazeIEnd;
    ProjLineIntersectWithBorder(
        mRayOriginProjX.xz, 
        mRayDirectionProjX.x / mRayDirectionProjX.z,
        gridSize.xy,
        xSize,
        grazeIStart,
        grazeIEnd
    );
    if (abs(mRayDirection.y) < 0.2f)
    {
        iStart = grazeIStart;
        iEnd = grazeIEnd;
    }

    int i;

    // x方向遍历
    // for (i = 0; i < int(gridSeg.x); i++)
    for (i = max(0, iStart - 1); i <= min(int(gridSeg.x - 1), iEnd + 1); i++)
    {
        cylinderStart = ObjectToWorldNoScale(
            float3(xStart + i * xSize, cylinderRadius, yStart)
        );
        cylinderEnd = ObjectToWorldNoScale(
            float3(xStart + i * xSize, cylinderRadius, -yStart)
        );
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
// Column柱状计算
bool intersectRayAABB(
    float3 rayOrigin, float3 rayDir,
    float3 boxMin, float3 boxMax,
    out float tNear, out float tFar
) {
    float3 invDir = 1.0 / rayDir;
    float3 t0s = (boxMin - rayOrigin) * invDir;
    float3 t1s = (boxMax - rayOrigin) * invDir;

    float3 tsmaller = min(t0s, t1s);
    float3 tbigger  = max(t0s, t1s);

    tNear = max(max(tsmaller.x, tsmaller.y), tsmaller.z);
    tFar  = min(min(tbigger.x, tbigger.y), tbigger.z);

    if (tFar < max(tNear, 0.0))
        return false;

    return true;
}

float RayPlaneIntersect(
    float3 rayOrigin, float3 rayDirection,
    float3 planeNormal, float3 planePos
){
    float denom = dot(planeNormal, rayDirection);
    float t = dot(planePos - rayOrigin, planeNormal) / denom;
    return t;
}

float TestPointWithLineXZ(float2 A, float2 B, float2 P) 
{
    float2 v1 = B - A;
    float2 v2 = P - A;
    float s = sign(v1.x * v2.y - v1.y * v2.x);
    return s == 0.0f ? 1.0f : s;
}

bool ComputeIntervalWithH(
    float y1, 
    float y2, 
    float expandRadius,
    float halfCHeight,
    float vertStep,
    out int index1, 
    out int index2)
{
    float pH = clamp(y1, -halfCHeight + expandRadius, halfCHeight + expandRadius) + halfCHeight - expandRadius;
    float pOffsetH = clamp(y2, -halfCHeight + expandRadius, halfCHeight + expandRadius) + halfCHeight - expandRadius;
    int index = floor(pH / (vertStep));
    int indexOffset = floor(pOffsetH / (vertStep));

    bool isSameIndex = index == indexOffset;
    float rH = pH - index * vertStep;
    float rOffsetH = pOffsetH - indexOffset * vertStep;
    float minH = min(rH, rOffsetH);
    float maxH = max(rH, rOffsetH);

    bool isIncluded = maxH <= (vertStep - 2 * expandRadius);
    if (isIncluded && isSameIndex) {
        return false;
    }

    index1 = index + 1;
    index2 = indexOffset + 1;
    return true;
}

HitProperties PlaneCylinderHit(
    float3 rayOrigin, 
    float3 rayDirection, 
    float tNear,
    float tFar,
    int side, 
    float expandRadius,
    float halfCHeight,
    float halfCLength,
    float halfCWidth,
    float vertStep,
    float secRadius,
    int verticalSeg)
{
    HitProperties horiHit;
    horiHit.isHit = false;
    float3 horiCylPointList[4] = { 
        float3(-halfCLength - expandRadius, 0, -halfCWidth - expandRadius), 
        float3(-halfCLength - expandRadius, 0, halfCWidth + expandRadius),
        float3(halfCLength + expandRadius, 0, halfCWidth + expandRadius),
        float3(halfCLength + expandRadius, 0, -halfCWidth - expandRadius)       
    };

    float3 mappingNormal[4] = {
        float3(0, 0, -1), float3(-1, 0, 0), 
        float3(0, 0, 1), float3(1, 0, 0)
    };

    float3 normal = mappingNormal[side];

    float3 mRayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    float3 mRayOrigin = WorldToObjectNoScale(rayOrigin);

    int jStart, jEnd;
    //与平面平行
    if (abs(dot(mRayDirection, normal)) < 0.06f) {
        float pNearY = (mRayOrigin + mRayDirection * tNear).y;
        float pFarY = (mRayOrigin + mRayDirection * tFar).y;
        if (!ComputeIntervalWithH(pNearY, pFarY, expandRadius, halfCHeight, vertStep, jStart, jEnd))
        {
            return horiHit;
        }
    }
    else {
        float3 boundingBox[4][2] = {
            {
                float3(-halfCLength - 2 * expandRadius, -halfCHeight, -halfCWidth - 2 * expandRadius),
                float3(halfCLength + 2 * expandRadius, halfCHeight, -halfCWidth)
            },
            {
                float3(-halfCLength - 2 * expandRadius, -halfCHeight, -halfCWidth - 2 * expandRadius),
                float3(-halfCLength, halfCHeight, halfCWidth + 2 * expandRadius)
            },
            {
                float3(-halfCLength - 2 * expandRadius, -halfCHeight, halfCWidth),
                float3(halfCLength + 2 * expandRadius, halfCHeight, halfCWidth + 2 * expandRadius)
            },
            {
                float3(halfCLength, -halfCHeight, -halfCWidth - 2 * expandRadius),
                float3(halfCLength + 2 * expandRadius, halfCHeight, halfCWidth + 2 * expandRadius)
            },
        };

        float3 lw = float3(halfCLength + expandRadius, 0, halfCWidth + expandRadius);
        float3 offset = float3(expandRadius, 0, expandRadius);
        float sig = -sign(dot(mRayDirection, normal));
        float3 nearPlanePos = normal * lw + offset * normal * sig;
        float3 farPlanePos = normal * lw + offset * normal * (-sig);
        float3 bMin = boundingBox[side][0];
        float3 bMax = boundingBox[side][1];
        intersectRayAABB(mRayOrigin, mRayDirection, bMin, bMax, tNear, tFar);
        float pNearY = (mRayOrigin + mRayDirection * tNear).y;
        float pFarY = (mRayOrigin + mRayDirection * tFar).y;

        if (!ComputeIntervalWithH(pNearY, pFarY, expandRadius, halfCHeight, vertStep, jStart, jEnd)){
            return horiHit;
        }
    }

    // jStart = 1;
    // jEnd = verticalSeg;
    int dir = sign(dot(mRayDirection, float3(0, 1, 0)));

    int index = (side + 3) % 4;
    jStart = min(jStart, jEnd);
    jEnd = max(jStart, jEnd);
    for (int j = max(1, jStart - 1); j <= min(verticalSeg, jEnd + 1); ++j) {
    // for (int j = max(1, jStart - 1); j <= min(verticalSeg, jStart + 1); ++j) {
        HitProperties hit = CylinderHitSphere(
            rayOrigin, rayDirection, 
            ObjectToWorldNoScale(horiCylPointList[index] + float3(0, -halfCHeight + j * vertStep, 0)), 
            ObjectToWorldNoScale(horiCylPointList[(index + 1) % 4] + float3(0, -halfCHeight + j * vertStep, 0)), 
            secRadius
        ); // 0->(-1,0,0), 1->(0,0,1), 2->(1,0,0), 3->(0,0,-1)
        if (hit.isHit) {
            if (!horiHit.isHit || length(hit.hitPoint - rayOrigin) < length(horiHit.hitPoint - rayOrigin)) {
                horiHit = hit;
            }
        }
    }
    return horiHit;
}
// 利用前面的函数预计算
HitProperties ColumnHit(float3 rayOrigin, float3 rayDirection, 
    float3 columnLWH, float vertSeg, float cylinderRadius, float secRadius)
{
    float cLength = columnLWH.x, cWidth = columnLWH.y, cHeight = columnLWH.z;
    int verticalSeg = int(vertSeg);

    HitProperties hitProp, vertHit, horiHit;
    hitProp.isHit = false;
    vertHit.isHit = false;
    horiHit.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    float halfCLength = cLength * 0.5;
    float halfCWidth = cWidth * 0.5;
    float halfCHeight = cHeight * 0.5;

    // 判断是否命中四根垂直圆柱
    float3 vertCylStartList[4] = {
        float3(-halfCLength, halfCHeight, -halfCWidth),
        float3(-halfCLength, halfCHeight, halfCWidth),
        float3(halfCLength, halfCHeight, -halfCWidth),
        float3(halfCLength, halfCHeight, halfCWidth)
    };
    float3 vertCylEndList[4] = {
        float3(-halfCLength, -halfCHeight, -halfCWidth),
        float3(-halfCLength, -halfCHeight, halfCWidth),
        float3(halfCLength, -halfCHeight, -halfCWidth),
        float3(halfCLength, -halfCHeight, halfCWidth)
    };
    int i;
    for (i = 0; i < 4; ++i) {
        HitProperties hit = CylinderHit(rayOrigin, rayDirection, 
            ObjectToWorldNoScale(vertCylStartList[i]), ObjectToWorldNoScale(vertCylEndList[i]), cylinderRadius);
        if (hit.isHit) {
            if (!vertHit.isHit || length(hit.hitPoint - rayOrigin) < length(vertHit.hitPoint - rayOrigin)) {
                vertHit = hit;
            }
        }
    }


    // 预计算AABB
    float3 mRayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    float3 mRayOrigin = WorldToObjectNoScale(rayOrigin);
    
    float expandRadius = cylinderRadius + secRadius;
    float vertStep = cHeight / (verticalSeg + 1);

    float3 OuterTestPoint[4] = {
        float3(-halfCLength -  2 * expandRadius, 0, -halfCWidth - 2 * expandRadius), 
        float3(-halfCLength - 2 * expandRadius, 0, halfCWidth + 2 * expandRadius),
        float3(halfCLength + 2 * expandRadius, 0, halfCWidth + 2 * expandRadius),
        float3(halfCLength + 2 * expandRadius, 0, -halfCWidth - 2 * expandRadius)       
    };

    float3 InnerTestPoint[4] = {
        float3(-halfCLength, 0, -halfCWidth), 
        float3(-halfCLength, 0, halfCWidth),
        float3(halfCLength, 0, halfCWidth),
        float3(halfCLength, 0, -halfCWidth)       
    };

    float3 bMin = float3(-halfCLength - 2 * expandRadius, -halfCHeight, -halfCWidth - 2 * expandRadius);
    float3 bMax = float3(halfCLength + 2 * expandRadius, halfCHeight, halfCWidth + 2 * expandRadius);
    float tNear, tFar;
    // 计算交点
    // if (!intersectRayAABB(mRayOrigin, mRayDirection, bMin, bMax, tNear, tFar)) return hitProp;
    intersectRayAABB(mRayOrigin, mRayDirection, bMin, bMax, tNear, tFar);

    int mappingSide[16][3] = {
        {-1, -1, -1},  //0
        {-1, -1, -1},  //1
        {-1, -1, -1},  //2
        {0, 1, -1},    //3
        {-1, -1, -1},  //4
        {0, 2, -1},    //5
        {1, 2, -1},    //6
        {0, 1, 2},     //7
        {-1, -1, -1},  //8
        {0, 3, -1},    //9
        {1, 3, -1},    //10
        {0, 1, 3},     //11
        {2, 3, -1},    //12
        {0, 2, 3},     //13
        {1, 2, 3},     //14
        {-1, -1, -1}   //15
    };

    int IntersectSide[16] = {
        0, 3, 6, 5,
        12, 0, 10, 9,
        9, 10, 0, 12,
        5, 6, 3, 0
        // {4, 4}, {0, 1}, {1, 2}, {0, 2},
        // {2, 3}, {-1, -1}, {1, 3}, {0, 3},
        // {3, 0}, {3, 1}, {-1, -1}, {3, 2},
        // {2, 0}, {2, 1}, {1, 0}, {4, 4}
    };  
    //outerState,innerState分别是内外4点的测试情况 每个点从xOz平面的左下角编码
    //二进制位从低位到高位分别对应编号为0，1，2，3的点的测试情况，点在直线的左侧时，对应的二进制位为1，否则为0

    //IntersectSide数组是outerState, innerState对应的面编码后的值。例如，编码后的值为3，转化为二进制是0011，实际上穿过的面就是0和1号面

    //mappingSide数组将IntersectSide映射为需要求交的面的数字编号。例如，index = 3时，转化为二进制是0011，对应0和1号面，所以mappingSide[3]存0，1
    uint outerState = 0, innerState = 0;
    
    [unroll] 
    for (i = 0; i < 4; ++i) {
        float signVal = TestPointWithLineXZ(mRayOrigin.xz,mRayOrigin.xz + mRayDirection.xz, OuterTestPoint[i].xz);
        signVal = signVal * 0.5f + 0.5f;
        outerState |= (1 << i) * int(signVal);
        signVal = TestPointWithLineXZ(mRayOrigin.xz,mRayOrigin.xz + mRayDirection.xz, InnerTestPoint[i].xz);
        signVal = signVal * 0.5f + 0.5f;
        innerState |= (1 << i) * int(signVal);
    }

    int sidesIn = IntersectSide[innerState];
    int sidesOut = IntersectSide[outerState];
    int sidesInOut = sidesIn | sidesOut;                // 取相关面的并集
    int sideNum = lerp(2, 3, sign(sidesIn ^ sidesOut)); // 0 -> 2 >1 -> 3 //如果sidesIn == sidesOut，那么需要测试的面的个数为2个，否则为3个

    if (sidesIn == 0 || sidesIn == 15){                 //内部4个点测试结果为1111和0000时的情况
        [unroll]
        for (i = 0; i < 4; ++i) {
            HitProperties hit = PlaneCylinderHit(rayOrigin, rayDirection, tNear, tFar, i, expandRadius, halfCHeight, halfCLength, halfCWidth, vertStep, secRadius, verticalSeg);
            if (hit.isHit) {
                if (!horiHit.isHit || length(hit.hitPoint - rayOrigin) < length(horiHit.hitPoint - rayOrigin)) {
                horiHit = hit;
                }
            }
        }
    }
    else {
        [unroll]
        for (i = 0; i < sideNum; ++i) {
            int side = mappingSide[sidesInOut][i];
            HitProperties hit = PlaneCylinderHit(rayOrigin, rayDirection, tNear, tFar, side, expandRadius, halfCHeight, halfCLength, halfCWidth, vertStep, secRadius, verticalSeg);
            if (hit.isHit) {
                if (!horiHit.isHit || length(hit.hitPoint - rayOrigin) < length(horiHit.hitPoint - rayOrigin)) {
                    horiHit = hit;
                }
            }
        }
    } 
        
    if (vertHit.isHit && horiHit.isHit) {
        if(length(vertHit.hitPoint - rayOrigin) < length(horiHit.hitPoint - rayOrigin)) 
            hitProp = vertHit;
        else hitProp = horiHit;
        // hitProp = length(vertHit.hitPoint - rayOrigin) < length(horiHit.hitPoint - rayOrigin) ? vertHit : horiHit;
    }
    else if (vertHit.isHit) hitProp = vertHit;
    else if (horiHit.isHit) hitProp = horiHit;

    // hitProp.testColor = float3((min(verticalSeg, jEnd + 1) - max(1, jStart - 1)) *1.0 / 9 * 255, 0, 0);

    return hitProp;
}


// Torus圆弧计算
HitProperties TorusHit(float3 rayOrigin, float3 rayDirection, 
    float arcRadius, float cylinderRadius)
{
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    // 圆弧的圆心在物体的0,0,0，圆心在Y轴上，应用旋转矩阵
    // float3 center = ObjectToWorldNoScale(float3(1, 0, 1));
    // float3 normal = normalize(ObjectToWorldNoScaleDir(float3(1, 1, 1)));
    float3 center = float3(0, 0, 0);
    float3 normal = float3(0, 1, 0);
    // normal = normalize(normal - center); // 修正法向量

    rayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    rayOrigin = WorldToObjectNoScale(rayOrigin);

    float3 vec, pos = rayOrigin, project;
    int iterNum = 50;
    float minDist = 0.01f, maxDist = 100.0f;
    float curDist = 0;
    for(int i = 0; i < iterNum; ++i)
    {
        // 根据Torus SDF计算距离
        pos += rayDirection * curDist;
        vec = pos - center;
        project = vec - dot(vec, normal) * normal;
        project = arcRadius / length(project) * project; // 投影缩放至圆弧
        // curDist = length(vec - project) - cylinderRadius;
        curDist = length(float2(length(pos.xz) - arcRadius, pos.y)) - cylinderRadius;

        // 命中
        if(curDist < minDist)
        {
            hitProp.isHit = true;
            hitProp.hitPoint = ObjectToWorldNoScale(pos); 
            hitProp.hitNormal = normalize(ObjectToWorldNoScaleDir(vec - project));
            break;
        }
        // 未命中
        if(curDist > maxDist) break;
    }

    return hitProp;
}



// Newtonian Torus
// 计算代入 Torus 方程后的四次方程
float f_t(float t, float3 rayOrigin, float3 rayDirection, 
    float arcRadius, float cylinderRadius) 
{
    float3 P = rayOrigin + t * rayDirection;
    float x = P.x, y = P.y, z = P.z;
    float temp = sqrt(x * x + z * z) - arcRadius;
    return temp * temp + y * y - cylinderRadius * cylinderRadius;
}
// 计算导数 f'(t)
float df_t(float t, float3 rayOrigin, float3 rayDirection, 
    float arcRadius) 
{
    float3 P = rayOrigin + t * rayDirection;
    float x = P.x, y = P.y, z = P.z;
    
    float temp = sqrt(x * x + z * z) - arcRadius;
    
    // 偏导数
    float dx_dt = rayDirection.x, dy_dt = rayDirection.y, dz_dt = rayDirection.z;
    float dTemp_dt = (x * dx_dt + z * dz_dt) / sqrt(x * x + z * z);
    
    return 2.0 * temp * dTemp_dt + 2.0 * y * dy_dt;
}
HitProperties NewtonianTorusHit(float3 rayOrigin, float3 rayDirection, 
    float arcRadius, float cylinderRadius)
{
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    rayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    rayOrigin = WorldToObjectNoScale(rayOrigin);

    int maxIter = 10;
    float minDist = 0.01f;
    float curDist = 0;
    float t; // 根据SDF选初值

    int i;
    float march = 0;
    float3 pos = rayOrigin;
    // 利用SDF快速定位初值
    for (i = 0; i < 10; i++) {
        pos += rayDirection * march;
        march = length(float2(length(pos.xz) - arcRadius, pos.y)) - cylinderRadius;        
    }   
    t = length(pos - rayOrigin);

    for (i = 0; i < maxIter; i++) {
        float ft = f_t(t, rayOrigin, rayDirection, arcRadius, cylinderRadius);
        float dft = df_t(t, rayOrigin, rayDirection, arcRadius);
        
        // 避免除零错误
        if (abs(dft) < 1e-6) break;

        // Newton-Raphson 迭代
        float t_next = t - ft / dft;

        pos = rayOrigin + t_next * rayDirection;
        curDist = length(float2(length(pos.xz) - arcRadius, pos.y)) - cylinderRadius;
        
        // 误差足够小则收敛
        if (curDist < minDist) {
            hitProp.isHit = true;
            hitProp.hitPoint = ObjectToWorldNoScale(pos);
            float3 project = float3(pos.x, 0, pos.z);
            project = arcRadius / length(project) * project; // 投影缩放至圆弧
            hitProp.hitNormal = normalize(ObjectToWorldNoScaleDir(pos - project));
            break;
        }

        t = t_next;
    }

    return hitProp;
}

// ---------------------------------补充数值求解方法-----------------------------------
bool IntersectCylinder(float3 O, float3 D, float3 A, float3 B, float r, out float t, out float3 P, out float3 normal) {
    float3 C = B - A;
    float lenC_sq = dot(C, C);
    if (lenC_sq < 1e-6) return false; // 圆柱退化为点，无交点

    float lenC = sqrt(lenC_sq);
    float3 C_dir = C / lenC;
    float3 OA = O - A;

    // 侧面相交测试
    float3 cross_OA_C = cross(OA, C);
    float3 cross_D_C = cross(D, C);
    float a = dot(cross_D_C, cross_D_C);
    float b = 2 * dot(cross_OA_C, cross_D_C);
    float c = dot(cross_OA_C, cross_OA_C) - r * r * lenC_sq;
    float delta = b * b - 4 * a * c;

    float s_side = -1;
    float t_proj = 0;

    if (delta >= 0) {
        float sqrt_delta = sqrt(delta);
        float s0 = (-b - sqrt_delta) / (2 * a);
        float s1 = (-b + sqrt_delta) / (2 * a);

        // 检查两个解的有效性
        [unroll]
        for (int i = 0; i < 2; i++) {
            float s = (i == 0) ? s0 : s1;
            if (s >= 0) {
                float3 P_side = O + s * D;
                float proj = dot(P_side - A, C);
                float t_proj_side = proj / lenC_sq;
                if (t_proj_side >= 0 && t_proj_side <= 1) {
                    if (s_side < 0 || s < s_side) {
                        s_side = s;
                        t_proj = t_proj_side;
                    }
                }
            }
        }
    }
    else return false; // 无交点

    // 底面A（起点端面）相交测试
    float s_capA = -1;
    float3 capA_normal = -C_dir;
    float denomA = dot(D, capA_normal);
    if (abs(denomA) > 1e-6) {
        float s = dot(A - O, capA_normal) / denomA;
        if (s >= 0) {
            float3 P_cap = O + s * D;
            float3 AP = P_cap - A;
            if (dot(AP, AP) <= r * r) {
                s_capA = s;
            }
        }
    }

    // 底面B（终点端面）相交测试
    float s_capB = -1;
    float3 capB_normal = C_dir;
    float denomB = dot(D, capB_normal);
    if (abs(denomB) > 1e-6) {
        float s = dot(B - O, capB_normal) / denomB;
        if (s >= 0) {
            float3 P_cap = O + s * D;
            float3 BP = P_cap - B;
            if (dot(BP, BP) <= r * r) {
                s_capB = s;
            }
        }
    }

    // 确定最近的交点
    float min_s = -1;
    bool hit_side = false, hit_capA = false, hit_capB = false;

    if (s_side >= 0) {
        min_s = s_side;
        hit_side = true;
    }
    if (s_capA >= 0 && (s_capA < min_s || min_s < 0)) {
        min_s = s_capA;
        hit_side = false;
        hit_capA = true;
        hit_capB = false; // 确保只选择一个端面
    }
    if (s_capB >= 0 && (s_capB < min_s || min_s < 0)) {
        min_s = s_capB;
        hit_side = false;
        hit_capB = true;
        hit_capA = false; // 确保只选择一个端面
    }

    if (min_s < 0) return false; // 无交点

    t = min_s;
    P = O + t * D;

    // 计算法线方向
    if (hit_side) {
        float3 Q = A + t_proj * C; // 轴线上的投影点
        normal = normalize(P - Q); // 侧面法线垂直于轴线
    } else if (hit_capA) {
        normal = capA_normal; // 底面A法线朝外
    } else {
        normal = capB_normal; // 底面B法线朝外
    }

    return true;
}

HitProperties IntersectCylinderNumerical(float3 rayOrigin, float3 rayDirection, 
    float3 cylinderStart, float3 cylinderEnd, float cylinderRadius){
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    float t;
    float3 P, normal;
    hitProp.isHit = IntersectCylinder(rayOrigin, rayDirection, 
        cylinderStart, cylinderEnd, cylinderRadius, t, P, normal);
    hitProp.hitPoint = P;
    hitProp.hitNormal = normal;
    return hitProp;
}


#endif