#include <metal_stdlib>
using namespace metal;
struct VIn { float4 position [[attribute(0)]];
float3 input1 [[attribute(1)]];
};
struct VOut { float4 position [[position]];
float3 input1;
};
vertex VOut coopdx_vertex(VIn in [[stage_in]]) { VOut o; o.position=in.position;
o.input1=in.input1;
return o; }
fragment float4 coopdx_fragment(VOut in [[stage_in]], texture2d<float> tex0 [[texture(0)]], texture2d<float> tex1 [[texture(1)]], sampler samp0 [[sampler(0)]], sampler samp1 [[sampler(1)]], constant float3 &lightMapColor [[buffer(0)]], constant float &frameCount [[buffer(1)]], constant int *shaderFlags [[buffer(2)]], constant float *shaderFlagValues [[buffer(3)]], constant int &filterMode [[buffer(4)]], constant uint *tileFilters [[buffer(5)]]) {
float4 combined=float4(0.0);
combined=float4(in.input1,1.0);
combined.a=1.0;
return combined; }
