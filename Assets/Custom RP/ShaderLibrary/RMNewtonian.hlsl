#ifndef RAY_MARCHING_NEWTONIAN_INCLUDED
#define RAY_MARCHING_NEWTONIAN_INCLUDED

void BranchlessONB(in const float3 n, out float3 b1, out float3 b2) {
    float sign = n.z>= 0.0f ? 1.0f:-1.0f;
    const float a = -1.0f / (sign + n.z);
    const float b = n.x * n.y * a;
    b1 = float3(1.0f + sign * n.x * n.x * a, sign * b, -sign * n.x);
    b2 = float3(b, sign + n.y * n.y * a, -n.y);
}

bool Intersect(float r, 
               float3 c0,
               float3 cd,
               float correctFactor,
               out float dt, 
               out float s,
               out float3 p
              ) { 
    // ray.o = {0,0,0}; ray.d = {0,0,1};
    // cone is defined by base center c0, radius r,
    // axis cd, and slant dr
    float r2 = r * r; 
    float cdz2 = cd.z * cd.z;
    float dc0cd = dot(c0, cd);
    p = float3(0, 0, dc0cd / cd.z); // ray ∩ plane in p;

    float c = 1 - cdz2; // compute a, b, c in
    float b = cd.z * dc0cd - c0.z; // a + 2 b s + c s2
    float a = dot(c0, c0) - dc0cd * dc0cd - r2;

    float det = b * b - a * c; // for a + 2 b s + c s2
    s = (-b - (det > 0 ? sqrt(det) : 0)) / c; // c > 0
    dt = clamp(dot(cd, float3(0, 0, s) - c0), -0.05, 0.05) / 1;

    //dt = dot(cd, float3(0, 0, s) - c0) / correctFactor;

    return det > 0; // true (real) or false (phantom)
}

void T2TorusRayCentricCoord(float arcRadius, float3 pos, float3x3 mat, float t, out float3 c0, out float3 cd, out float length)
{
    float theta = 3.1415926 * t / 2;
    c0 = mul(mat, arcRadius * float3(cos(theta), 0, sin(theta)) - pos);
    cd = mul(mat, float3(-sin(theta), 0, cos(theta)));
    length = 1;
} //ray-centric space

void T2CylinderRayCentricCoord(float arcRadius, float3 pos, float3x3 mat, float t, out float3 c0, out float3 cd, out float length)
{
    c0 = mul(mat, float3(t, 0, 0) - pos);
    cd = mul(mat, float3(1, 0, 0));
    length = 1;
} //ray-centric space

// 通过quadraticConfig传入二次函数的三个系数
// #define A 2
// #define B 2
// #define c -1

// 通过shader feature编译不同的分支
// #define QUAD
// #define TORUS

void T2QuadraticFuncRayCentricCoord(
    float3 quadraConfig,
    float arcRadius, float3 pos, float3x3 mat, float t, out float3 c0, out float3 cd, out float length
) //Ax^2+Bx+c
{
    float x = t * arcRadius;
    c0 = mul(mat, float3(x, 0, quadraConfig.x * x * x + quadraConfig.y * x + quadraConfig.z) - pos);
    cd = mul(mat, normalize(float3(arcRadius, 0, 2 * quadraConfig.x * x * arcRadius + arcRadius * quadraConfig.y)));
    float ar2 = arcRadius * arcRadius;
    float ar = arcRadius;
    length = quadraConfig.x * ar2 / 3 + quadraConfig.y * ar / 2 + quadraConfig.z;
}

HitProperties FindingRoot(
                          float3 quadraConfig,
                          float arcRadius, 
                          float cylinderRadius, 
                          float3 pos, 
                          float3x3 mat,
                          float3x3 transMat,
                          float t,
                          float maxIterFindingInterval,
                          float maxIterFindingRoot,
                          float minDist){
    float3 c0, cd, p;
    float lastT, lastDt, s, dt, length;

    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);

    #if defined(_RAY_MARCHING_QUADRA)
    T2QuadraticFuncRayCentricCoord(quadraConfig, arcRadius, pos, mat, t, c0, cd, length);
    #endif
    #if defined(_RAY_MARCHING_ARC)
    T2TorusRayCentricCoord(arcRadius, pos, mat, t, c0, cd, length);
    #endif
    //T2CylinderRayCentricCoord(arcRadius, pos, mat, t, c0, cd);
    Intersect(cylinderRadius, c0, cd, length, dt, s, p);

    lastT = t;
    lastDt = dt;
    t += dt;

    for (int i = 0; i < maxIterFindingInterval; i++) {
        #if defined(_RAY_MARCHING_QUADRA)
        T2QuadraticFuncRayCentricCoord(quadraConfig, arcRadius, pos, mat, t, c0, cd, length);
        #endif
        #if defined(_RAY_MARCHING_ARC)
        T2TorusRayCentricCoord(arcRadius, pos, mat, t, c0, cd, length);
        #endif
        //T2CylinderRayCentricCoord(arcRadius, pos, mat, t, c0, cd);
        Intersect(cylinderRadius, c0, cd, length, dt, s, p);

        if (dt * lastDt < 0) { //dt and lastDt have the different sign
            break;
        }
        lastT = t;
        lastDt = dt;
        t += dt;
    } //find the start interval [lastT, t] or [t, lastT]

    float tl, tr, dtl, dtr;
    if (lastT < t) {
        tl = lastT;
        dtl = lastDt;
        tr = t;
        dtr = dt;
    }
    else {
        tl = t;
        dtl = dt;
        tr = lastT;
        dtr = lastDt;
    }

    float tTest, dtTest;
    
    for (int i = 0; i < maxIterFindingRoot; i++){
        tTest = (dtr * tl - dtl * tr) / (dtr - dtl);
        if (i & 3 == 0) tTest = (tl + tr) * 0.5;
        #if defined(_RAY_MARCHING_QUADRA)
        T2QuadraticFuncRayCentricCoord(quadraConfig, arcRadius, pos, mat, tTest, c0, cd, length);
        #endif
        #if defined(_RAY_MARCHING_ARC)
        T2TorusRayCentricCoord(arcRadius, pos, mat, tTest, c0, cd, length);
        #endif
        //T2CylinderRayCentricCoord(arcRadius, pos, mat, tTest, c0, cd);

        if (Intersect(cylinderRadius, c0, cd, length, dtTest, s, p) && abs(dtTest) < minDist){
            if (tTest < 0 || tTest > 1) {
                break;
            }
            float3 rayCentricNorm = normalize(s * float3(0, 0, 1) - c0);
            hitProp.isHit = true;
            hitProp.hitPoint = ObjectToWorldNoScale(pos + mul(transMat, s * float3(0, 0, 1)));
            hitProp.hitNormal = normalize(ObjectToWorldNoScaleDir(mul(transMat, rayCentricNorm)));
            break;
        }

        if (dtTest * dtl > 0) {
            tl = tTest;
            dtl = dtTest;
        }
        else {
            tr = tTest;
            dtr = dtTest;
        }
    }

    return hitProp;
}


HitProperties PhantomTestHit(
    float3 quadraConfig,
    float3 rayOrigin, float3 rayDirection, 
    float arcRadius, float cylinderRadius
){
    HitProperties hitProp;
    hitProp.isHit = false;
    hitProp.hitPoint = float3(0, 0, 0);
    hitProp.hitNormal = float3(0, 0, 0);


    rayDirection = normalize(WorldToObjectNoScaleDir(rayDirection));
    rayOrigin = WorldToObjectNoScale(rayOrigin);

    int maxIterFindingInterval = 10;
    int maxIterFindingRoot = 50;
    float minDist = 0.00005f;
    float curDist = 0;

    int i;
    float3 pos = rayOrigin;

    float3 rayCentricD1 = rayDirection;
    float3 rayCentricD2, rayCentricD3;
    BranchlessONB(rayCentricD1, rayCentricD2, rayCentricD3);

    float3x3 mat = float3x3(rayCentricD2, rayCentricD3, rayCentricD1);
    float3x3 transMat = transpose(mat);

    float s, t, dt0, dt1, length;
    float3 t0c0, t0cd, t1c0, t1cd, p;
    float r2 = cylinderRadius * cylinderRadius;

    //intersect in buttend
    #if defined(_RAY_MARCHING_QUADRA)
    T2QuadraticFuncRayCentricCoord(quadraConfig, arcRadius, pos, mat, 0, t0c0, t0cd, length);
    #endif
    #if defined(_RAY_MARCHING_ARC)
    T2TorusRayCentricCoord(arcRadius, pos, mat, 0, t0c0, t0cd, length);
    #endif
    //T2CylinderRayCentricCoord(arcRadius, pos, mat, 0, t0c0, t0cd);
    Intersect(cylinderRadius, t0c0, t0cd, length, dt0, s, p);

    float vc2 = dot(p - t0c0, p - t0c0);
    if (dt0 < 0 && vc2 < r2 && dot(t0cd, float3(0, 0, 1)) > 0) {
        hitProp.isHit = true;
        hitProp.hitPoint = ObjectToWorldNoScale(pos + mul(transMat, p));
        hitProp.hitNormal = normalize(ObjectToWorldNoScaleDir(mul(transMat, -t0cd)));
        return hitProp;
    }

    //intersect in buttend
    #if defined(_RAY_MARCHING_QUADRA)
    T2QuadraticFuncRayCentricCoord(quadraConfig, arcRadius, pos, mat, 1, t1c0, t1cd, length);
    #endif
    #if defined(_RAY_MARCHING_ARC)
    T2TorusRayCentricCoord(arcRadius, pos, mat, 1, t1c0, t1cd, length);
    #endif
    //T2CylinderRayCentricCoord(arcRadius, pos, mat, 1, t1c0, t1cd);
    Intersect(cylinderRadius, t1c0, t1cd, length, dt1, s, p);

    vc2 = dot(p - t1c0, p - t1c0);
    if (dt1 > 0 && vc2 < r2 && dot(t1cd, float3(0, 0, 1)) < 0) {
        hitProp.isHit = true;
        hitProp.hitPoint = ObjectToWorldNoScale(pos + mul(transMat, p));
        hitProp.hitNormal = normalize(ObjectToWorldNoScaleDir(mul(transMat, t1cd)));
        return hitProp;
    }

    if (dt0 < 0 && dt1 > 0) return hitProp;

    if (dot(t1c0 - t0c0, float3(0, 0, 1)) > 0) t = 0; 
    else t = 1;

    hitProp = FindingRoot(quadraConfig, arcRadius, cylinderRadius, pos, mat, transMat, t, maxIterFindingInterval, maxIterFindingRoot, minDist);

    if (!hitProp.isHit) hitProp = FindingRoot(quadraConfig, arcRadius, cylinderRadius, pos, mat, transMat, 1 - t, maxIterFindingInterval, maxIterFindingRoot, minDist);


    return hitProp;
}

#endif //RAY_MARCHING_NEWTONIAN_INCLUDED