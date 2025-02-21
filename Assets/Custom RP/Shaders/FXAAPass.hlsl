#ifndef CUSTOM_FXAA_PASS_INCLUDED
#define CUSTOM_FXAA_PASS_INCLUDED

float4 _FXAAConfig;

float GetLuma (float2 uv, float uOffset = 0.0, float vOffset = 0.0) { // 在亮度上进行抗锯齿
    uv += float2(uOffset, vOffset) * GetSourceTexelSize().xy; // 采样相邻像素

	// return sqrt(Luminance(GetSource(uv)));    
    #if defined(FXAA_ALPHA_CONTAINS_LUMA)
    // 读取透明度通道上按上式计算的更好的亮度
		return GetSource(uv).a;
	#else
    // 视觉上对绿色敏感，规避点积与平方根（Gamma）运算
		return GetSource(uv).g;
	#endif
}

struct LumaNeighborhood {
	float m, n, e, s, w, ne, se, sw, nw;
    float highest, lowest, range;
};
LumaNeighborhood GetLumaNeighborhood (float2 uv) {
    // 在卷积核内工作
	LumaNeighborhood luma;
	luma.m = GetLuma(uv);
	luma.n = GetLuma(uv, 0.0, 1.0);
	luma.e = GetLuma(uv, 1.0, 0.0);
	luma.s = GetLuma(uv, 0.0, -1.0);
	luma.w = GetLuma(uv, -1.0, 0.0);
    luma.ne = GetLuma(uv, 1.0, 1.0);
	luma.se = GetLuma(uv, 1.0, -1.0);
	luma.sw = GetLuma(uv, -1.0, -1.0);
	luma.nw = GetLuma(uv, -1.0, 1.0);
    luma.highest = max(max(max(max(luma.m, luma.n), luma.e), luma.s), luma.w);
	luma.lowest = min(min(min(min(luma.m, luma.n), luma.e), luma.s), luma.w);
    luma.range = luma.highest - luma.lowest;
	return luma;
}

bool IsHorizontalEdge (LumaNeighborhood luma) {
    // 引入对角领域来提高边缘检测的质量
	float horizontal =
		2.0 * abs(luma.n + luma.s - 2.0 * luma.m) +
		abs(luma.ne + luma.se - 2.0 * luma.e) +
		abs(luma.nw + luma.sw - 2.0 * luma.w);
	float vertical =
		2.0 * abs(luma.e + luma.w - 2.0 * luma.m) +
		abs(luma.ne + luma.nw - 2.0 * luma.n) +
		abs(luma.se + luma.sw - 2.0 * luma.s);
	return horizontal >= vertical;
}
struct FXAAEdge {
	bool isHorizontal;
    float pixelStep; // 在屏幕空间的像素大小
    float lumaGradient, otherLuma;
};
FXAAEdge GetFXAAEdge (LumaNeighborhood luma) {
	FXAAEdge edge;
	edge.isHorizontal = IsHorizontalEdge(luma);
    // 上正下负，右正左负
    float lumaP, lumaN;
    if (edge.isHorizontal) {
        // xy分量本是纹理大小，由于纹理限制在三角形内，变为像素大小
		edge.pixelStep = GetSourceTexelSize().y;
        lumaP = luma.n;
		lumaN = luma.s;
	}
	else {
		edge.pixelStep = GetSourceTexelSize().x;
        lumaP = luma.e;
		lumaN = luma.w;
	}

    float gradientP = abs(lumaP - luma.m);
	float gradientN = abs(lumaN - luma.m);
    if (gradientP < gradientN) {
		edge.pixelStep = -edge.pixelStep;
        edge.lumaGradient = gradientN;
		edge.otherLuma = lumaN;
	}
    else {
		edge.lumaGradient = gradientP;
		edge.otherLuma = lumaP;
	}

	return edge;
}

bool CanSkipFXAA (LumaNeighborhood luma) {
	return luma.range < max(_FXAAConfig.x, _FXAAConfig.y * luma.highest);
}
float GetSubpixelBlendFactor (LumaNeighborhood luma) {
	float filter = 2.0 * (luma.n + luma.e + luma.s + luma.w); // 水平与垂直系数2
	filter += luma.ne + luma.nw + luma.se + luma.sw; // 对角系数1
	filter *= 1.0 / 12.0; // 低通滤波
    filter = abs(filter - luma.m); // 高通滤波
    filter = saturate(filter / luma.range); // 归一化
	filter = smoothstep(0, 1, filter); // 平方平滑
	return filter * filter * _FXAAConfig.z; // 控制混合因子平衡细节
}

#if defined(FXAA_QUALITY_LOW)
	#define EXTRA_EDGE_STEPS 3
	#define EDGE_STEP_SIZES 1.5, 2.0, 2.0
	#define LAST_EDGE_STEP_GUESS 8.0
#elif defined(FXAA_QUALITY_MEDIUM)
	#define EXTRA_EDGE_STEPS 8
	#define EDGE_STEP_SIZES 1.5, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 4.0
	#define LAST_EDGE_STEP_GUESS 8.0
#else
	#define EXTRA_EDGE_STEPS 10
	#define EDGE_STEP_SIZES 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0
	#define LAST_EDGE_STEP_GUESS 8.0
#endif
static const float edgeStepSizes[EXTRA_EDGE_STEPS] = { EDGE_STEP_SIZES };
float GetEdgeBlendFactor (LumaNeighborhood luma, FXAAEdge edge, float2 uv) {
	float2 edgeUV = uv;
    float2 uvStep = 0.0;
	if (edge.isHorizontal) {
		edgeUV.y += 0.5 * edge.pixelStep;
        uvStep.x = GetSourceTexelSize().x;
	}
	else {
		edgeUV.x += 0.5 * edge.pixelStep;
        uvStep.y = GetSourceTexelSize().y;
	}

    float edgeLuma = 0.5 * (luma.m + edge.otherLuma);
	float gradientThreshold = 0.25 * edge.lumaGradient;

    float2 uvP = edgeUV + uvStep;
	float lumaDeltaP = GetLuma(uvP) - edgeLuma;
	bool atEndP = abs(lumaDeltaP) >= gradientThreshold;

    int i;
    UNITY_UNROLL // 循环展开，略微提高性能
    for (i = 0; i < EXTRA_EDGE_STEPS && !atEndP; i++) {
		uvP += uvStep * edgeStepSizes[i];
		lumaDeltaP = GetLuma(uvP) - edgeLuma;
		atEndP = abs(lumaDeltaP) >= gradientThreshold;
	}
    if (!atEndP) {
		uvP += uvStep * LAST_EDGE_STEP_GUESS;
	}
    
    float2 uvN = edgeUV - uvStep;
	float lumaDeltaN = GetLuma(uvN) - edgeLuma;
	bool atEndN = abs(lumaDeltaN) >= gradientThreshold;

    UNITY_UNROLL
	for (i = 0; i < EXTRA_EDGE_STEPS && !atEndN; i++) {
		uvN -= uvStep * edgeStepSizes[i];
		lumaDeltaN = GetLuma(uvN) - edgeLuma;
		atEndN = abs(lumaDeltaN) >= gradientThreshold;
	}
    if (!atEndN) {
		uvN -= uvStep * LAST_EDGE_STEP_GUESS;
	}
	
	float distanceToEndP, distanceToEndN;
	if (edge.isHorizontal) {
		distanceToEndP = uvP.x - uv.x;
		distanceToEndN = uv.x - uvN.x;
	}
	else {
		distanceToEndP = uvP.y - uv.y;
		distanceToEndN = uv.y - uvN.y;
	}

	float distanceToNearestEnd;
    bool deltaSign;
	if (distanceToEndP <= distanceToEndN) {
		distanceToNearestEnd = distanceToEndP;
        deltaSign = lumaDeltaP >= 0;
	}
	else {
		distanceToNearestEnd = distanceToEndN;
        deltaSign = lumaDeltaN >= 0;
	}
	
	if (deltaSign == (luma.m - edgeLuma >= 0)) {
		return 0.0;
	}
	else {
		return 0.5 - distanceToNearestEnd / (distanceToEndP + distanceToEndN);
	}
}

float4 FXAAPassFragment (Varyings input) : SV_TARGET {
	LumaNeighborhood luma = GetLumaNeighborhood(input.screenUV);

    if (CanSkipFXAA(luma)) {
		return GetSource(input.screenUV);
	}

	FXAAEdge edge = GetFXAAEdge(luma);
	float blendFactor = max(
		GetSubpixelBlendFactor(luma), GetEdgeBlendFactor (luma, edge, input.screenUV)
	);
	float2 blendUV = input.screenUV;
    // 混合的结果与纹理的采样方式有关，像素之间的值
	if (edge.isHorizontal) {
		blendUV.y += blendFactor * edge.pixelStep;
	}
	else {
		blendUV.x += blendFactor * edge.pixelStep;
	}
	return GetSource(blendUV);
}

#endif