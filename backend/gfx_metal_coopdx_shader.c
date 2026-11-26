#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#include "gfx_metal_coopdx_shader.h"

struct Writer {
    char *data;
    size_t capacity;
    size_t length;
    bool valid;
};

static void append(struct Writer *w, const char *format, ...) {
    if (!w->valid || w->length >= w->capacity) {
        w->valid = false;
        return;
    }
    va_list args;
    va_start(args, format);
    int n = vsnprintf(w->data + w->length, w->capacity - w->length, format, args);
    va_end(args);
    if (n < 0 || (size_t)n >= w->capacity - w->length) {
        w->valid = false;
        return;
    }
    w->length += (size_t)n;
}

bool gfx_metal_coopdx_shader_key(const struct ColorCombiner *combiner,
                                 struct GfxMetalCoopDXShaderKey *key) {
    if (!combiner || !key) return false;
    memcpy(key->bytes, combiner->cm.all_values, 16);
    uint32_t flags = combiner->cm.flags & 0x7fu;
    memcpy(key->bytes + 16, &flags, sizeof(flags));
    memcpy(key->bytes + 20, combiner->shader_input_mapping, 16);
    memcpy(key->bytes + 36, combiner->shader_commands, 16);
    return true;
}

bool gfx_metal_coopdx_shader_key_equal(const struct GfxMetalCoopDXShaderKey *a,
                                       const struct GfxMetalCoopDXShaderKey *b) {
    return a && b && memcmp(a->bytes, b->bytes, GFX_METAL_COOPDX_KEY_SIZE) == 0;
}

static const char *input_type(bool alpha) { return alpha ? "float4" : "float3"; }

static const char *input_expr(uint8_t command, bool alpha) {
    static const char *names[] = {
        "float3(0.0)", "in.input1", "in.input2", "in.input3", "in.input4",
        "in.input5", "in.input6", "in.input7", "in.input8"
    };
    if (command >= SHADER_INPUT_1 && command <= SHADER_INPUT_8) {
        const char *name = names[command - SHADER_INPUT_1 + 1];
        if (!alpha) return name;
        return name;
    }
    return NULL;
}

static void emit_value(struct Writer *w, uint8_t command, bool rgb, bool alpha, bool single_element) {
    const char *input = input_expr(command, alpha);
    if (input) {
        append(w, "%s%s", input, rgb && alpha ? ".rgb" : (!rgb ? ".a" : ""));
        return;
    }
    switch (command) {
        case SHADER_0: append(w, rgb ? (alpha ? "float3(0.0)" : "float3(0.0)") : "0.0"); break;
        case SHADER_1: append(w, rgb ? "float3(1.0)" : "1.0"); break;
        case SHADER_TEXEL0: append(w, rgb ? (alpha ? "texel0.rgb" : "texel0.rgb") : "texel0.a"); break;
        case SHADER_TEXEL0A:
            if (!rgb || single_element) append(w, "texel0.a");
            else append(w, "float3(texel0.a)");
            break;
        case SHADER_TEXEL1: append(w, rgb ? "texel1.rgb" : "texel1.a"); break;
        case SHADER_TEXEL1A:
            if (!rgb || single_element) append(w, "texel1.a");
            else append(w, "float3(texel1.a)");
            break;
        case SHADER_COMBINED: append(w, rgb ? "combined.rgb" : "combined.a"); break;
        case SHADER_COMBINEDA:
            if (!rgb || single_element) append(w, "combined.a");
            else append(w, "float3(combined.a)");
            break;
        case SHADER_NOISE: append(w, rgb ? "float3(noise)" : "noise"); break;
        default: w->valid = false; break;
    }
}

static void emit_formula(struct Writer *w, const uint8_t *cmd, bool rgb, bool alpha) {
    if (rgb) {
        uint8_t a = cmd[0], b = cmd[1], c = cmd[2], d = cmd[3];
        if (c == SHADER_0) {
            emit_value(w, d, true, alpha, false);
        } else if (b == SHADER_0 && d == SHADER_0) {
            emit_value(w, a, true, alpha, false);
            append(w, " * ");
            emit_value(w, c, true, alpha, true);
        } else if (b == d) {
            append(w, "mix("); emit_value(w, b, true, alpha, false); append(w, ", ");
            emit_value(w, a, true, alpha, false); append(w, ", ");
            emit_value(w, c, true, alpha, true); append(w, ")");
        } else {
            append(w, "("); emit_value(w, a, true, alpha, false); append(w, " - ");
            emit_value(w, b, true, alpha, false); append(w, ") * ");
            emit_value(w, c, true, alpha, true); append(w, " + ");
            emit_value(w, d, true, alpha, false);
        }
    } else {
        uint8_t a = cmd[4], b = cmd[5], c = cmd[6], d = cmd[7];
        if (c == SHADER_0) {
            emit_value(w, d, false, alpha, false);
        } else if (b == SHADER_0 && d == SHADER_0) {
            emit_value(w, a, false, alpha, false); append(w, " * ");
            emit_value(w, c, false, alpha, true);
        } else if (b == d) {
            append(w, "mix("); emit_value(w, b, false, alpha, false); append(w, ", ");
            emit_value(w, a, false, alpha, false); append(w, ", ");
            emit_value(w, c, false, alpha, true); append(w, ")");
        } else {
            append(w, "("); emit_value(w, a, false, alpha, false); append(w, " - ");
            emit_value(w, b, false, alpha, false); append(w, ") * ");
            emit_value(w, c, false, alpha, true); append(w, " + ");
            emit_value(w, d, false, alpha, false);
        }
    }
}

static void emit_vertex(struct Writer *w, const struct GfxMetalCoopDXShaderInfo *info) {
    append(w, "#include <metal_stdlib>\nusing namespace metal;\n");
    append(w, "struct VIn { float4 position [[attribute(0)]];\n");
    uint32_t attribute = 1;
    for (int t = 0; t < 2; ++t) if (info->features.used_textures[t]) append(w, "float2 uv%d [[attribute(%u)]];\n", t, attribute++);
    if (info->fog) append(w, "float4 fog [[attribute(%u)]];\n", attribute++);
    if (info->light_map) append(w, "float2 lightMap [[attribute(%u)]];\n", attribute++);
    for (int i = 0; i < info->features.num_inputs; ++i) append(w, "%s input%d [[attribute(%u)]];\n", input_type(info->alpha), i + 1, attribute++);
    append(w, "};\nstruct VOut { float4 position [[position]];\n");
    for (int t = 0; t < 2; ++t) if (info->features.used_textures[t]) append(w, "float2 uv%d;\n", t);
    if (info->fog) append(w, "float4 fog;\n");
    if (info->light_map) append(w, "float2 lightMap;\n");
    for (int i = 0; i < info->features.num_inputs; ++i) append(w, "%s input%d;\n", input_type(info->alpha), i + 1);
    append(w, "};\nvertex VOut coopdx_vertex(VIn in [[stage_in]]) { VOut o; o.position=in.position;\n");
    for (int t = 0; t < 2; ++t) if (info->features.used_textures[t]) append(w, "o.uv%d=in.uv%d;\n", t, t);
    if (info->fog) append(w, "o.fog=in.fog;\n");
    if (info->light_map) append(w, "o.lightMap=in.lightMap;\n");
    for (int i = 0; i < info->features.num_inputs; ++i) append(w, "o.input%d=in.input%d;\n", i + 1, i + 1);
    append(w, "return o; }\n");
    (void)attribute;
}

static void emit_world_helpers(struct Writer *w) {
    append(w, "float3 rgb2hsv(float3 c) { float4 K=float4(0.0,-1.0/3.0,2.0/3.0,-1.0); float4 p=mix(float4(c.bg,K.wz),float4(c.gb,K.xy),step(c.b,c.g)); float4 q=mix(float4(p.xyw,c.r),float4(c.r,p.yzx),step(p.x,c.r)); float d=q.x-min(q.w,q.y); float e=1.0e-10; return float3(abs(q.z+(q.w-q.y)/(6.0*d+e)),d/(q.x+e),q.x); }\n");
    append(w, "float3 hsv2rgb(float3 c) { float3 p=abs(fract(c.xxx+float3(0.0,2.0/3.0,1.0/3.0))*6.0-3.0); return c.z*mix(float3(1.0),clamp(p-1.0,0.0,1.0),c.y); }\n");
    append(w, "float coopdx_dither4x4(float2 p,float brightness) { int x=int(fmod(p.x,4.0)); int y=int(fmod(p.y,4.0)); int i=x+y*4; const float m[16]={0.0625,0.5625,0.1875,0.6875,0.8125,0.3125,0.9375,0.4375,0.25,0.75,0.125,0.625,1.0,0.5,0.875,0.375}; return brightness<m[i]?0.0:1.0; }\n");
}

static void emit_filter_helper(struct Writer *w) {
    append(w, "float4 coopdx_sample(texture2d<float> tex,sampler smp,float2 uv,bool dofilter,int filterMode) { if(dofilter && filterMode==2) { float2 size=float2(tex.get_width(),tex.get_height()); float2 offset=fract(uv*size-float2(0.5)); offset-=step(1.0,offset.x+offset.y); float4 c0=tex.sample(smp,uv-offset/size); float4 c1=tex.sample(smp,uv-float2(offset.x-sign(offset.x),offset.y)/size); float4 c2=tex.sample(smp,uv-float2(offset.x,offset.y-sign(offset.y))/size); return c0+abs(offset.x)*(c1-c0)+abs(offset.y)*(c2-c0); } return tex.sample(smp,uv); }\n");
}

bool gfx_metal_coopdx_build_shader(const struct ColorCombiner *combiner,
                                   char *source, size_t source_size,
                                   struct GfxMetalCoopDXShaderInfo *info) {
    if (!combiner || !source || !info || source_size < 2) return false;
    memset(info, 0, sizeof(*info));
    source[0] = '\0';
    gfx_cc_get_features((struct ColorCombiner *)combiner, &info->features);
    info->alpha = combiner->cm.use_alpha;
    info->fog = combiner->cm.use_fog;
    info->texture_edge = combiner->cm.texture_edge;
    info->two_cycle = combiner->cm.use_2cycle;
    info->light_map = combiner->cm.light_map;
    info->world_geometry = combiner->cm.world_geometry;

    uint32_t attribute = 1;
    for (int t = 0; t < 2; ++t) if (info->features.used_textures[t]) attribute++;
    if (info->fog) attribute++;
    if (info->light_map) attribute++;
    attribute += (uint32_t)info->features.num_inputs;
    info->attribute_count = (uint8_t)attribute;
    uint32_t floats = 4;
    for (int t = 0; t < 2; ++t) if (info->features.used_textures[t]) floats += 2;
    if (info->fog) floats += 4;
    if (info->light_map) floats += 2;
    floats += (uint32_t)info->features.num_inputs * (info->alpha ? 4u : 3u);
    if (floats > UINT16_MAX / sizeof(float)) return false;
    info->vertex_stride = (uint16_t)(floats * sizeof(float));

    struct Writer w = { source, source_size, 0, true };
    emit_vertex(&w, info);
    if (info->world_geometry) emit_world_helpers(&w);
    if (info->features.used_textures[0] || info->features.used_textures[1]) emit_filter_helper(&w);
    append(&w, "fragment float4 coopdx_fragment(VOut in [[stage_in]], texture2d<float> tex0 [[texture(0)]], texture2d<float> tex1 [[texture(1)]], sampler samp0 [[sampler(0)]], sampler samp1 [[sampler(1)]], constant float3 &lightMapColor [[buffer(0)]], constant float &frameCount [[buffer(1)]], constant int *shaderFlags [[buffer(2)]], constant float *shaderFlagValues [[buffer(3)]], constant int &filterMode [[buffer(4)]], constant uint *tileFilters [[buffer(5)]]) {\n");
    if (info->features.used_textures[0]) append(&w, "float4 texel0=coopdx_sample(tex0,samp0,in.uv0,tileFilters[0]!=0,filterMode);\n");
    if (info->features.used_textures[1]) {
        append(&w, "float2 uv1=%s; float4 texel1=coopdx_sample(tex1,samp1,uv1,tileFilters[1]!=0,filterMode);\n",
               info->light_map ? "in.lightMap" : "in.uv1");
        if (info->light_map) {
            if (info->features.used_textures[0]) append(&w, "texel0.rgb*=lightMapColor;\n");
            append(&w, "texel1.rgb=texel1.rgb*texel1.rgb+texel1.rgb;\n");
        }
    }
    if (info->features.do_noise) append(&w, "float noise=fract(sin(dot(floor(in.position.xy)+float2(frameCount,frameCount*0.37),float2(12.9898,78.233)))*43758.5453);\n");
    append(&w, "float4 combined=float4(0.0);\n");
    int cycles = info->two_cycle ? 2 : 1;
    for (int cycle = 0; cycle < cycles; ++cycle) {
        const uint8_t *commands = &combiner->shader_commands[cycle * 8];
        append(&w, "combined=float4(");
        emit_formula(&w, commands, true, info->alpha);
        append(&w, ",");
        if (info->alpha) emit_formula(&w, commands, false, true);
        else append(&w, "1.0");
        append(&w, ");\n");
    }
    if (info->texture_edge && info->alpha) append(&w, "if(combined.a>0.3) combined.a=1.0; else discard_fragment();\n");
    if (info->world_geometry) {
        append(&w, "if(shaderFlags[0]==1) { float3 hsv=rgb2hsv(combined.rgb); hsv.x=fract(hsv.x+shaderFlagValues[0]); combined.rgb=hsv2rgb(hsv); }\n");
        append(&w, "if(shaderFlags[1]==1) { const float3 w=float3(0.2125,0.7154,0.0721); float3 intensity=float3(dot(combined.rgb,w)); combined.rgb=mix(intensity,combined.rgb,shaderFlagValues[1]); }\n");
        append(&w, "if(shaderFlags[2]==1) combined.rgb*=shaderFlagValues[2];\n");
        append(&w, "if(shaderFlags[3]==1) combined.rgb=float3(0.5)+shaderFlagValues[3]*(combined.rgb-float3(0.5));\n");
        append(&w, "if(shaderFlags[4]==1) combined.rgb*=shaderFlagValues[4];\n");
        append(&w, "if(shaderFlags[5]==1) combined.rgb*=coopdx_dither4x4(in.position.xy,dot(combined.rgb,float3(0.299,0.587,0.114)));\n");
        append(&w, "if(shaderFlags[6]==1) { float levels=float(int(max(1.0,shaderFlagValues[6]))); combined.rgb=floor(combined.rgb*levels)/levels; }\n");
        append(&w, "if(shaderFlags[7]==1) { float scan=sin(in.position.y*1.5)*0.04; combined.rgb-=scan*shaderFlagValues[7]; }\n");
    }
    if (info->fog) append(&w, "combined.rgb=mix(combined.rgb,in.fog.rgb,in.fog.a);\n");
    if (!info->alpha) append(&w, "combined.a=1.0;\n");
    append(&w, "return combined; }\n");
    return w.valid;
}
