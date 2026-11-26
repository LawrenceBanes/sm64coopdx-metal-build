from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
BACKEND = (ROOT / "backend/gfx_metal_coopdx.m").read_text()
API = (ROOT / "backend/gfx_metal_coopdx.h").read_text()


class BackendContractTests(unittest.TestCase):
    def test_backend_exports_registration_and_runtime_status(self):
        self.assertIn("struct GfxRenderingAPI gfx_metal_coopdx_api", API)
        self.assertIn("bool gfx_metal_coopdx_is_ready(void)", API)
        self.assertIn("gfx_metal_coopdx_api = {", BACKEND)

    def test_alpha_pipeline_and_depth_write_callbacks_exist(self):
        self.assertIn("blendingEnabled = YES", BACKEND)
        self.assertIn("metal_set_depth_mask", BACKEND)
        self.assertIn("depthWriteEnabled = d && w", BACKEND)
        self.assertIn("metal_set_depth_mask, metal_set_decal", BACKEND)

    def test_texture_replacement_rebind_and_upload_are_runtime_state(self):
        self.assertIn("sSelectedTexture[tile] =", BACKEND)
        self.assertIn("id<MTLTexture> texture = [sDevice newTextureWithDescriptor:d]", BACKEND)
        self.assertIn("sTextures[id] = texture", BACKEND)
        self.assertIn("setFragmentTexture:t atIndex:tile", BACKEND)

    def test_dynos_material_paths_share_texture_and_combiner_backend(self):
        self.assertIn("gfx_metal_coopdx_build_shader(cc, source", BACKEND)
        self.assertIn("gfx_metal_coopdx_shader_key(cc, &key)", BACKEND)
        self.assertIn("sProgram->pipeline[sAlpha ? 1 : 0]", BACKEND)

    def test_frame_and_presentation_paths_use_drawable_command_buffer(self):
        self.assertIn("nextDrawable", BACKEND)
        self.assertIn("renderCommandEncoderWithDescriptor", BACKEND)
        self.assertIn("presentDrawable:sDrawable", BACKEND)
        self.assertIn("[sCommandBuffer commit]", BACKEND)

    def test_adapter_exports_backend_recovery_status_hooks(self):
        # Selection and OpenGL fallback are owned by the app's graphics manager;
        # this isolated backend only exports the status probes it needs there.
        self.assertIn("gfx_metal_coopdx_is_ready", API)
        self.assertIn("gfx_metal_coopdx_had_pipeline_error", API)


if __name__ == "__main__":
    unittest.main(verbosity=2)
