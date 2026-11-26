#include <metal_stdlib>
using namespace metal;
struct VIn { float4 position [[attribute(0)]];
float2 uv1 [[attribute(1)]];
};
struct VOut { float4 position [[position]];
float2 uv1;
};
vertex VOut coopdx_vertex(VIn in [[stage_in]]) { VOut o; o.position=in.position;
o.uv1=in.uv1;
return o; }
float4 coopdx_sample(texture2d<float> tex,sampler smp,float2 uv,bool dofilter,int filterMode) { if(dofilter && filterMode==2) { float2 size=float2(tex.get_width(),tex.get_height()); float2 offset=fract(uv*size-float2(0.5)); offset-=step(1.0,offset.x+offset.y); float4 c0=tex.sample(smp,uv-offset/size); float4 c1=tex.sample(smp,uv-float2(offset.x-sign(offset.x),offset.y)/size); float4 c2=tex.sample(smp,uv-float2(offset.x,offset.y-sign(offset.y))/size); return c0+abs(offset.x)*(c1-c0)+abs(offset.y)*(c2-c0); } return tex.sample(smp,uv); }
fragment float4 coopdx_fragment(VOut in [[stage_in]], texture2d<float> tex0 [[texture(0)]], texture2d<float> tex1 [[texture(1)]], sampler samp0 [[sampler(0)]], sampler samp1 [[sampler(1)]], constant float3 &lightMapColor [[buffer(0)]], constant float &frameCount [[buffer(1)]], constant int *shaderFlags [[buffer(2)]], constant float *shaderFlagValues [[buffer(3)]], constant int &filterMode [[buffer(4)]], constant uint *tileFilters [[buffer(5)]]) {
float2 uv1=in.uv1; float4 texel1=coopdx_sample(tex1,samp1,uv1,tileFilters[1]!=0,filterMode);
float4 combined=float4(0.0);
combined=float4(texel1.rgb * float3(1.0),1.0);
combined.a=1.0;
return combined; }
