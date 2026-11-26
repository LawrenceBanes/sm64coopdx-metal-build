#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <dispatch/dispatch.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL_metal.h>
#include <PR/gbi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gfx_metal_coopdx.h"
#include "gfx_metal_coopdx_rect.h"
#include "gfx_metal_coopdx_shader.h"
#include "gfx_metal_coopdx_stream.h"
#include "gfx_sdl.h"
#include "gfx_pc.h"
#include "gfx_cc.h"
#include "pc/configfile.h"

#define METAL_SHADER_LIMIT 64
#define METAL_TEXTURE_LIMIT 32768
#define METAL_MAX_BUFFER_BYTES (32u * 1024u * 1024u)
#define METAL_MAX_TEXTURE_BYTES (256u * 1024u * 1024u)
#define METAL_MAX_SINGLE_TEXTURE_BYTES (16u * 1024u * 1024u)
#define METAL_FRAMES_IN_FLIGHT 3

struct MetalVertexFrame {
    id<MTLBuffer> buffer;
    id<MTLTexture> depth;
    NSUInteger capacity;
    struct GfxMetalCoopDXVertexStream stream;
    size_t growthTarget;
};

struct MetalProgram {
    struct GfxMetalCoopDXShaderKey key;
    struct GfxMetalCoopDXShaderInfo info;
    id<MTLRenderPipelineState> pipeline[2];
};

static id<MTLDevice> sDevice;
static id<MTLCommandQueue> sQueue;
static id<CAMetalDrawable> sDrawable;
static id<MTLCommandBuffer> sCommandBuffer;
static id<MTLRenderCommandEncoder> sEncoder;
static struct MetalVertexFrame sVertexFrames[METAL_FRAMES_IN_FLIGHT];
static NSUInteger sVertexFrameIndex;
static dispatch_semaphore_t sFrameSemaphore;
static bool sFramePermit;
static NSUInteger sTextureBytes;
static struct MetalProgram sPrograms[METAL_SHADER_LIMIT];
static NSUInteger sProgramCount;
static id<MTLTexture> sTextures[METAL_TEXTURE_LIMIT];
static uint32_t sNextTexture = 1;
static id<MTLTexture> sWhiteTexture;
static id<MTLDepthStencilState> sDepthStates[2][2];
static id<MTLSamplerState> sSamplers[2];
static bool sLinear[2];
static uint32_t sWrapS[2], sWrapT[2];
static uint32_t sSelectedTexture[2];
static int sUploadTile;
static struct MetalProgram *sProgram;
static bool sAlpha, sDepthEnabled = true, sDepthWrite = true, sDecal;
static bool sScissorEmpty;
static NSUInteger sWidth, sHeight;
static uint32_t sFrame;
static bool sReady;
static bool sPipelineError;

static bool metal_z_is_zero_to_one(void) { return true; }
bool gfx_metal_coopdx_is_ready(void) { return sReady; }
bool gfx_metal_coopdx_had_pipeline_error(void) { return sPipelineError; }

static id<MTLTexture> make_white_texture(void) {
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead;
    d.storageMode = MTLStorageModeShared;
    id<MTLTexture> t = [sDevice newTextureWithDescriptor:d];
    const uint8_t white[4] = { 255, 255, 255, 255 };
    [t replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0 withBytes:white bytesPerRow:4];
    return t;
}

static MTLAddressMode address_mode(uint32_t mode) {
    if (mode & G_TX_CLAMP) return MTLAddressModeClampToEdge;
    if (mode & G_TX_MIRROR) return MTLAddressModeMirrorRepeat;
    return MTLAddressModeRepeat;
}

static void update_sampler(int tile) {
    if (tile < 0 || tile > 1 || !sDevice) return;
    MTLSamplerDescriptor *d = [[MTLSamplerDescriptor alloc] init];
    d.minFilter = sLinear[tile] ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
    d.magFilter = sLinear[tile] ? MTLSamplerMinMagFilterLinear : MTLSamplerMinMagFilterNearest;
    d.mipFilter = MTLSamplerMipFilterNotMipmapped;
    d.sAddressMode = address_mode(sWrapS[tile]);
    d.tAddressMode = address_mode(sWrapT[tile]);
    sSamplers[tile] = [sDevice newSamplerStateWithDescriptor:d];
}

static MTLVertexFormat vertex_format(uint8_t size) {
    switch (size) {
        case 2: return MTLVertexFormatFloat2;
        case 3: return MTLVertexFormatFloat3;
        default: return MTLVertexFormatFloat4;
    }
}

/* Build from the original combiner on first lookup; full semantic keying avoids relying on its hash. */
static id<MTLRenderPipelineState> make_pipeline(struct ColorCombiner *cc, struct MetalProgram *p, bool blend) {
    char source[32768];
    struct GfxMetalCoopDXShaderInfo info;
    if (!gfx_metal_coopdx_build_shader(cc, source, sizeof(source), &info)) { sPipelineError = true; return nil; }
    NSError *error = nil;
    NSString *msl = [NSString stringWithUTF8String:source];
    id<MTLLibrary> library = [sDevice newLibraryWithSource:msl options:nil error:&error];
    if (!library) {
        sPipelineError = true;
        fprintf(stderr, "Metal combiner compile failed: %s\n", error.localizedDescription.UTF8String ?: "unknown error");
        return nil;
    }
    id<MTLFunction> vertex = [library newFunctionWithName:@"coopdx_vertex"];
    id<MTLFunction> fragment = [library newFunctionWithName:@"coopdx_fragment"];
    if (!vertex || !fragment) {
        sPipelineError = true;
        fprintf(stderr, "Metal combiner library is missing required entry points\n");
        return nil;
    }

    MTLVertexDescriptor *vd = [[MTLVertexDescriptor alloc] init];
    uint32_t attribute = 0, offset = 0;
    vd.attributes[attribute].format = MTLVertexFormatFloat4;
    vd.attributes[attribute].offset = offset; vd.attributes[attribute].bufferIndex = 0;
    offset += 4 * sizeof(float); attribute++;
    for (int t = 0; t < 2; ++t) if (info.features.used_textures[t]) {
        vd.attributes[attribute].format = MTLVertexFormatFloat2;
        vd.attributes[attribute].offset = offset; vd.attributes[attribute].bufferIndex = 0;
        offset += 2 * sizeof(float); attribute++;
    }
    if (info.fog) {
        vd.attributes[attribute].format = MTLVertexFormatFloat4;
        vd.attributes[attribute].offset = offset; vd.attributes[attribute].bufferIndex = 0;
        offset += 4 * sizeof(float); attribute++;
    }
    if (info.light_map) {
        vd.attributes[attribute].format = MTLVertexFormatFloat2;
        vd.attributes[attribute].offset = offset; vd.attributes[attribute].bufferIndex = 0;
        offset += 2 * sizeof(float); attribute++;
    }
    for (int i = 0; i < info.features.num_inputs; ++i) {
        uint8_t n = info.alpha ? 4 : 3;
        vd.attributes[attribute].format = vertex_format(n);
        vd.attributes[attribute].offset = offset; vd.attributes[attribute].bufferIndex = 0;
        offset += n * sizeof(float); attribute++;
    }
    vd.layouts[0].stride = offset;
    vd.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    MTLRenderPipelineDescriptor *d = [[MTLRenderPipelineDescriptor alloc] init];
    d.vertexFunction = vertex;
    d.fragmentFunction = fragment;
    d.vertexDescriptor = vd;
    d.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    if (blend) {
        d.colorAttachments[0].blendingEnabled = YES;
        d.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        d.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        d.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        d.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
        d.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        d.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    }
    id<MTLRenderPipelineState> pipeline = [sDevice newRenderPipelineStateWithDescriptor:d error:&error];
    if (!pipeline) { sPipelineError = true; fprintf(stderr, "Metal pipeline creation failed: %s\n", error.localizedDescription.UTF8String ?: "unknown error"); }
    else p->info = info;
    return pipeline;
}

static void metal_unload_shader(struct ShaderProgram *old) { (void)old; }
static void metal_load_shader(struct ShaderProgram *program) { sProgram = (struct MetalProgram *)program; }

static struct ShaderProgram *metal_lookup_shader(struct ColorCombiner *cc) {
    struct GfxMetalCoopDXShaderKey key;
    if (!sReady || !gfx_metal_coopdx_shader_key(cc, &key)) return NULL;
    for (NSUInteger i = 0; i < sProgramCount; ++i) {
        if (gfx_metal_coopdx_shader_key_equal(&sPrograms[i].key, &key)) return (struct ShaderProgram *)&sPrograms[i];
    }
    return NULL;
}

static struct ShaderProgram *metal_create_shader(struct ColorCombiner *cc) {
    struct MetalProgram *p = (struct MetalProgram *)metal_lookup_shader(cc);
    if (p) { sProgram = p; return (struct ShaderProgram *)p; }
    if (sProgramCount == METAL_SHADER_LIMIT) {
        fprintf(stderr, "Metal shader cache limit reached (%d)\n", METAL_SHADER_LIMIT);
        return NULL;
    }
    struct GfxMetalCoopDXShaderKey key;
    if (!gfx_metal_coopdx_shader_key(cc, &key)) return NULL;
    p = &sPrograms[sProgramCount];
    memset(p, 0, sizeof(*p));
    p->key = key;
    p->pipeline[0] = make_pipeline(cc, p, false);
    p->pipeline[1] = make_pipeline(cc, p, true);
    if (!p->pipeline[0] || !p->pipeline[1]) {
        sPipelineError = true;
        p->pipeline[0] = nil; p->pipeline[1] = nil;
        return NULL;
    }
    sProgramCount++;
    sProgram = p;
    return (struct ShaderProgram *)p;
}

static void metal_shader_get_info(struct ShaderProgram *program, uint8_t *numInputs, bool usedTextures[2]) {
    struct MetalProgram *p = (struct MetalProgram *)program;
    if (!p) {
        if (numInputs) *numInputs = 0;
        if (usedTextures) { usedTextures[0] = false; usedTextures[1] = false; }
        return;
    }
    if (numInputs) *numInputs = (uint8_t)p->info.features.num_inputs;
    if (usedTextures) { usedTextures[0] = p->info.features.used_textures[0]; usedTextures[1] = p->info.features.used_textures[1]; }
}

static uint32_t metal_new_texture(void) {
    if (sNextTexture >= METAL_TEXTURE_LIMIT) { fprintf(stderr, "Metal texture cache limit reached\n"); return 0; }
    return sNextTexture++;
}
static void metal_select_texture(int tile, uint32_t id) {
    if (tile < 0 || tile > 1) return;
    sUploadTile = tile;
    sSelectedTexture[tile] = id < METAL_TEXTURE_LIMIT ? id : 0;
}
static void metal_upload_texture(const uint8_t *rgba, int width, int height) {
    int tile = sUploadTile;
    uint32_t id = sSelectedTexture[tile];
    if (!rgba || width <= 0 || height <= 0 || width > 4096 || height > 4096 || id == 0 || id >= METAL_TEXTURE_LIMIT) return;
    NSUInteger bytes = (NSUInteger)width * (NSUInteger)height * 4;
    if (bytes > METAL_MAX_SINGLE_TEXTURE_BYTES) return;
    NSUInteger oldBytes = sTextures[id] ? sTextures[id].width * sTextures[id].height * 4 : 0;
    if (sTextureBytes - oldBytes + bytes > METAL_MAX_TEXTURE_BYTES) {
        fprintf(stderr, "Metal texture memory budget exceeded\n");
        return;
    }
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:(NSUInteger)width height:(NSUInteger)height mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead;
    d.storageMode = MTLStorageModeShared;
    id<MTLTexture> texture = [sDevice newTextureWithDescriptor:d];
    if (!texture) return;
    [texture replaceRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0 withBytes:rgba bytesPerRow:(NSUInteger)width * 4];
    sTextures[id] = texture;
    sTextureBytes = sTextureBytes - oldBytes + bytes;
}
static void metal_set_sampler(int tile, bool linear, uint32_t cms, uint32_t cmt) {
    if (tile < 0 || tile > 1) return;
    sLinear[tile] = linear; sWrapS[tile] = cms; sWrapT[tile] = cmt; update_sampler(tile);
}
static void metal_set_depth_test(bool enabled) { sDepthEnabled = enabled; }
static void metal_set_depth_mask(bool enabled) { sDepthWrite = enabled; }
static void metal_set_decal(bool enabled) { sDecal = enabled; }
static void metal_set_viewport(int x, int y, int w, int h) {
    if (!sEncoder || w <= 0 || h <= 0) return;
    MTLViewport v = { (double)x, (double)sHeight - (double)y - (double)h, (double)w, (double)h, 0.0, 1.0 };
    [sEncoder setViewport:v];
}
static void metal_set_scissor(int x, int y, int w, int h) {
    if (!sEncoder) return;
    struct GfxMetalCoopDXScissorRect rect;
    if (!gfx_metal_coopdx_clip_scissor(x, y, w, h, (uint32_t)sWidth, (uint32_t)sHeight, &rect)) {
        sScissorEmpty = true;
        return;
    }
    sScissorEmpty = false;
    [sEncoder setScissorRect:MTLScissorRectMake(rect.x, rect.y, rect.width, rect.height)];
}
static void metal_set_alpha(bool enabled) { sAlpha = enabled; }

static void metal_draw_triangles(float *vertices, size_t floatCount, size_t triangleCount) {
    if (!sEncoder || sScissorEmpty || !sProgram || !vertices || !triangleCount || triangleCount > UINT32_MAX / 3) return;
    id<MTLRenderPipelineState> pipeline = sProgram->pipeline[sAlpha ? 1 : 0];
    if (!pipeline) return;
    if (floatCount > METAL_MAX_BUFFER_BYTES / sizeof(float)) return;
    size_t bytes = floatCount * sizeof(float);
    if (bytes == 0 || bytes > METAL_MAX_BUFFER_BYTES) { fprintf(stderr, "Metal vertex batch rejected (%zu bytes)\n", bytes); return; }
    if (triangleCount * 3 * sProgram->info.vertex_stride != bytes) {
        fprintf(stderr, "Metal vertex batch stride mismatch\n");
        return;
    }
    size_t vertexOffset = 0;
    struct MetalVertexFrame *frame = &sVertexFrames[sVertexFrameIndex];
    if (!frame->buffer || !gfx_metal_coopdx_vertex_stream_reserve(
            &frame->stream, bytes, 256, frame->capacity,
            METAL_MAX_BUFFER_BYTES, &vertexOffset)) {
        if (frame->stream.required > frame->growthTarget) frame->growthTarget = frame->stream.required;
        return;
    }
    memcpy((uint8_t *)frame->buffer.contents + vertexOffset, vertices, bytes);
    [sEncoder setRenderPipelineState:pipeline];
    [sEncoder setDepthStencilState:sDepthStates[sDepthEnabled ? 1 : 0][sDepthWrite ? 1 : 0]];
    [sEncoder setDepthBias:sDecal ? -2.0 : 0.0 slopeScale:sDecal ? -2.0 : 0.0 clamp:0.0];
    [sEncoder setVertexBuffer:frame->buffer offset:vertexOffset atIndex:0];
    for (int tile = 0; tile < 2; ++tile) {
        id<MTLTexture> t = sTextures[sSelectedTexture[tile]] ?: sWhiteTexture;
        [sEncoder setFragmentTexture:t atIndex:tile];
        [sEncoder setFragmentSamplerState:sSamplers[tile] atIndex:tile];
    }
    vector_float3 color = (vector_float3){ gVertexColor[0] / 255.0f, gVertexColor[1] / 255.0f, gVertexColor[2] / 255.0f };
    [sEncoder setFragmentBytes:&color length:sizeof(color) atIndex:0];
    float frameNumber = (float)sFrame;
    [sEncoder setFragmentBytes:&frameNumber length:sizeof(frameNumber) atIndex:1];
    [sEncoder setFragmentBytes:gShaderFlags length:sizeof(gShaderFlags) atIndex:2];
    [sEncoder setFragmentBytes:gShaderFlagValues length:sizeof(gShaderFlagValues) atIndex:3];
    int filterMode = (int)configFiltering;
    [sEncoder setFragmentBytes:&filterMode length:sizeof(filterMode) atIndex:4];
    uint32_t tileFilters[2] = { sLinear[0] ? 1u : 0u, sLinear[1] ? 1u : 0u };
    [sEncoder setFragmentBytes:tileFilters length:sizeof(tileFilters) atIndex:5];
    [sEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:(NSUInteger)triangleCount * 3];
}

static void metal_init(void) {
    sReady = false;
    sPipelineError = false;
    sFrameSemaphore = dispatch_semaphore_create(METAL_FRAMES_IN_FLIGHT);
    if (!sFrameSemaphore) { fprintf(stderr, "Metal frame semaphore creation failed\n"); return; }
    for (int i = 0; i < METAL_FRAMES_IN_FLIGHT; ++i) sVertexFrames[i].growthTarget = 4096;
    id layerValue = (__bridge id)gfx_sdl_get_metal_layer();
    if (!gfx_sdl_uses_metal() || !layerValue) { fprintf(stderr, "Metal renderer requires an SDL Metal view\n"); return; }
    sDevice = MTLCreateSystemDefaultDevice();
    if (!sDevice) { fprintf(stderr, "No Metal device is available\n"); return; }
    sQueue = [sDevice newCommandQueue];
    if (!sQueue) { fprintf(stderr, "Metal command queue creation failed\n"); return; }
    CAMetalLayer *layer = (__bridge CAMetalLayer *)gfx_sdl_get_metal_layer();
    layer.device = sDevice;
    layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    layer.framebufferOnly = YES;
    layer.maximumDrawableCount = 3;
    sWhiteTexture = make_white_texture();
    for (int d = 0; d < 2; ++d) for (int w = 0; w < 2; ++w) {
        MTLDepthStencilDescriptor *desc = [[MTLDepthStencilDescriptor alloc] init];
        desc.depthCompareFunction = d ? MTLCompareFunctionLessEqual : MTLCompareFunctionAlways;
        desc.depthWriteEnabled = d && w;
        sDepthStates[d][w] = [sDevice newDepthStencilStateWithDescriptor:desc];
    }
    for (int t = 0; t < 2; ++t) { sWrapS[t] = G_TX_WRAP; sWrapT[t] = G_TX_WRAP; update_sampler(t); }
    sReady = sWhiteTexture && sDepthStates[0][0] && sDepthStates[1][1];
}

static void metal_resize(void) { sWidth = 0; sHeight = 0; }
static void metal_start_frame(void) {
    if (!sReady) return;
    dispatch_semaphore_wait(sFrameSemaphore, DISPATCH_TIME_FOREVER);
    sFramePermit = true;
    ++sFrame;
    sVertexFrameIndex = (sFrame - 1) % METAL_FRAMES_IN_FLIGHT;
    struct MetalVertexFrame *frame = &sVertexFrames[sVertexFrameIndex];
    if (frame->growthTarget > frame->capacity && frame->growthTarget <= METAL_MAX_BUFFER_BYTES) {
        NSUInteger capacity = 4096;
        while (capacity < frame->growthTarget && capacity < METAL_MAX_BUFFER_BYTES) capacity *= 2;
        if (capacity > METAL_MAX_BUFFER_BYTES) capacity = METAL_MAX_BUFFER_BYTES;
        id<MTLBuffer> replacement = [sDevice newBufferWithLength:capacity options:MTLResourceStorageModeShared];
        if (replacement) {
            frame->buffer = replacement;
            frame->capacity = capacity;
            frame->growthTarget = 0;
        } else {
            fprintf(stderr, "Metal vertex stream growth failed (%zu bytes requested)\n", frame->growthTarget);
        }
    }
    gfx_metal_coopdx_vertex_stream_reset(&frame->stream);
    sDrawable = [(CAMetalLayer *)gfx_sdl_get_metal_layer() nextDrawable];
    if (!sDrawable) {
        dispatch_semaphore_signal(sFrameSemaphore);
        sFramePermit = false;
        return;
    }
    sWidth = sDrawable.texture.width; sHeight = sDrawable.texture.height;
    sCommandBuffer = [sQueue commandBuffer];
    if (!sCommandBuffer) {
        sDrawable = nil;
        dispatch_semaphore_signal(sFrameSemaphore);
        sFramePermit = false;
        return;
    }
    dispatch_semaphore_t frameSemaphore = sFrameSemaphore;
    [sCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
        (void)commandBuffer;
        dispatch_semaphore_signal(frameSemaphore);
    }];
    sFramePermit = false;
    if (sWidth != frame->depth.width || sHeight != frame->depth.height) {
        MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:sWidth height:sHeight mipmapped:NO];
        d.usage = MTLTextureUsageRenderTarget;
        d.storageMode = MTLStorageModePrivate;
        frame->depth = [sDevice newTextureWithDescriptor:d];
    }
    if (!frame->depth) {
        sDrawable = nil;
        [sCommandBuffer commit];
        sCommandBuffer = nil;
        return;
    }
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = sDrawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    pass.depthAttachment.texture = frame->depth;
    pass.depthAttachment.loadAction = MTLLoadActionClear;
    pass.depthAttachment.storeAction = MTLStoreActionDontCare;
    pass.depthAttachment.clearDepth = 1.0;
    sEncoder = [sCommandBuffer renderCommandEncoderWithDescriptor:pass];
    sAlpha = false; sDepthEnabled = true; sDepthWrite = true; sDecal = false; sScissorEmpty = false;
}
static void metal_end_frame(void) {
    if (sEncoder) { [sEncoder endEncoding]; sEncoder = nil; }
}
static void metal_finish_render(void) {
    if (!sCommandBuffer) {
        if (sFramePermit) {
            dispatch_semaphore_signal(sFrameSemaphore);
            sFramePermit = false;
        }
        return;
    }
    if (sEncoder) metal_end_frame();
    if (sDrawable) [sCommandBuffer presentDrawable:sDrawable];
    [sCommandBuffer commit];
    sCommandBuffer = nil; sDrawable = nil;
}
static const char *metal_name(void) { return "Metal (CoopDX)"; }
static void metal_shutdown(void) {
    sReady = false;
    sEncoder = nil; sCommandBuffer = nil; sDrawable = nil;
    sProgram = NULL; sProgramCount = 0;
    for (int i = 0; i < METAL_FRAMES_IN_FLIGHT; ++i) {
        sVertexFrames[i].buffer = nil;
        sVertexFrames[i].depth = nil;
        sVertexFrames[i].capacity = 0;
        sVertexFrames[i].growthTarget = 0;
        gfx_metal_coopdx_vertex_stream_reset(&sVertexFrames[i].stream);
    }
    sFramePermit = false;
    sFrameSemaphore = nil;
    sTextureBytes = 0;
    sNextTexture = 1; sUploadTile = 0;
    memset(sSelectedTexture, 0, sizeof(sSelectedTexture));
    memset(sPrograms, 0, sizeof(sPrograms));
    for (NSUInteger i = 0; i < METAL_TEXTURE_LIMIT; ++i) sTextures[i] = nil;
    sDepthStates[0][0] = nil; sDepthStates[0][1] = nil;
    sDepthStates[1][0] = nil; sDepthStates[1][1] = nil;
    sSamplers[0] = nil; sSamplers[1] = nil;
    sDevice = nil; sQueue = nil; sWhiteTexture = nil;
}

struct GfxRenderingAPI gfx_metal_coopdx_api = {
    metal_z_is_zero_to_one, metal_unload_shader, metal_load_shader,
    metal_create_shader, metal_lookup_shader, metal_shader_get_info,
    metal_new_texture, metal_select_texture, metal_upload_texture, metal_set_sampler,
    metal_set_depth_test, metal_set_depth_mask, metal_set_decal, metal_set_viewport,
    metal_set_scissor, metal_set_alpha, metal_draw_triangles,
    metal_init, metal_resize, metal_start_frame, metal_end_frame, metal_finish_render,
    metal_name, metal_shutdown
};
