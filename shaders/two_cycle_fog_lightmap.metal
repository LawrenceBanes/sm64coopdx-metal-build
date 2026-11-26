#include <metal_stdlib>
using namespace metal;
struct VIn { float4 position [[attribute(0)]];
float2 uv0 [[attribute(1)]];
float2 uv1 [[attribute(2)]];
float4 fog [[attribute(3)]];
float2 lightMap [[attribute(4)]];
float4 input1 [[attribute(5)]];
float4 input2 [[attribute(6)]];
float4 input3 [[attribute(7)]];
};
struct VOut { float4 position [[position]];
float2 uv0;
float2 uv1;
float4 fog;
float2 lightMap;
float4 input1;
float4 input2;
float4 input3;
};
vertex VOut coopdx_vertex(VIn in [[stage_in]]) { VOut o; o.position=in.position;
o.uv0=in.uv0;
o.uv1=in.uv1;
o.fog=in.fog;
o.lightMap=in.lightMap;
o.input1=in.input1;
o.input2=in.input2;
o.input3=in.input3;
return o; }
float3 rgb2hsv(float3 c) { float4 K=float4(0.0,-1.0/3.0,2.0/3.0,-1.0); float4 p=mix(float4(c.bg,K.wz),float4(c.gb,K.xy),step(c.b,c.g)); float4 q=mix(float4(p.xyw,c.r),float4(c.r,p.yzx),step(p.x,c.r)); float d=q.x-min(q.w,q.y); float e=1.0e-10; return float3(abs(q.z+(q.w-q.y)/(6.0*d+e)),d/(q.x+e),q.x); }
float3 hsv2rgb(float3 c) { float3 p=abs(fract(c.xxx+float3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0); return c.z*mix(float3(1.0),clamp(p-1.0,0.0,1.0),c.y); }
float coopdx_dither4x4(float2 p,float brightness) { int x=int(fmod(p.x,4.0)); int y=int(fmod(p.y,4.0)); int i=x+y*4; const float m[16]={0.0625,0.5625,0.1875,0.6875,0.8125,0.3125,0.9375,0.4375,0.25,0.75,0.125,0.625,1.0,0.5,0.875,0.375}; return brightness<m[i]?0.0:1.0; }
float4 coopdx_sample(texture2d<float> tex,sampler smp,float2 uv,bool dofilter,int filterMode) { if(dofilter && filterMode==2) { float2 size=float2(tex.get_width(),tex.get_height()); float2 offset=fract(uv*size-float2(0.5)); offset-=step(1.0,offset.x+offset.y); float4 c0=tex.sample(smp,uv-offset/size); float4 c1=tex.sample(smp,uv-float2(offset.x-sign(offset.x),offset.y)/size); float4 c2=tex.sample(smp,uv-float2(offset.x,offset.y-sign(offset.y))/size); return c0+abs(offset.x)*(c1-c0)+abs(offset.y)*(c2-c0); } return tex.sample(smp,uv); }
fragment float4 coopdx_fragment(VOut in [[stage_in]], texture2d<float> tex0 [[texture(0)]], texture2d<float> tex1 [[texture(1)]], sampler samp0 [[sampler(0)]], sampler samp1 [[sampler(1)]], constant float3 &lightMapColor [[buffer(0)]], constant float &frameCount [[buffer(1)]], constant int *shaderFlags [[buffer(2)]], constant float *shaderFlagValues [[buffer(3)]], constant int &filterMode [[buffer(4)]], constant uint *tileFilters [[buffer(5)]]) {
float4 texel0=coopdx_sample(tex0,samp0,in.uv0,tileFilters[0]!=0,filterMode);
float2 uv1=in.lightMap; float4 texel1=coopdx_sample(tex1,samp1,uv1,tileFilters[1]!=0,filterMode);
texel0.rgb*=lightMapColor;
texel1.rgb=texel1.rgb*texel1.rgb+texel1.rgb;
float4 combined=float4(0.0);
combined=float4((texel0.rgb - in.input1.rgb) * in.input2.rgb + in.input3.rgb,(texel0.a - in.input1.a) * in.input2.a + in.input3.a);
combined=float4((texel1.rgb - float3(0.0)) * float3(1.0) + combined.rgb,(texel1.a - 0.0) * 1.0 + combined.a);
if(combined.a>0.3) combined.a=1.0; else discard_fragment();
if(shaderFlags[0]==1) { float3 hsv=rgb2hsv(combined.rgb); hsv.x=fract(hsv.x+shaderFlagValues[0]); combined.rgb=hsv2rgb(hsv); }
if(shaderFlags[1]==1) { const float3 w=float3(0.2125,0.7154,0.0721); float3 intensity=float3(dot(combined.rgb,w)); combined.rgb=mix(intensity,combined.rgb,shaderFlagValues[1]); }
if(shaderFlags[2]==1) combined.rgb*=shaderFlagValues[2];
if(shaderFlags[3]==1) combined.rgb=float3(0.5)+shaderFlagValues[3]*(combined.rgb-float3(0.5));
if(shaderFlags[4]==1) combined.rgb*=shaderFlagValues[4];
if(shaderFlags[5]==1) combined.rgb*=coopdx_dither4x4(in.position.xy,dot(combined.rgb,float3(0.299,0.587,0.114)));
if(shaderFlags[6]==1) { float levels=float(int(max(1.0,shaderFlagValues[6]))); combined.rgb=floor(combined.rgb*levels)/levels; }
if(shaderFlags[7]==1) { float scan=sin(in.position.y*1.5)*0.04; combined.rgb-=scan*shaderFlagValues[7]; }
combined.rgb=mix(combined.rgb,in.fog.rgb,in.fog.a);
return combined; }
