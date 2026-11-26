#include "gfx_cc.h"

void gfx_cc_get_features(struct ColorCombiner *combiner, struct CCFeatures *features) {
    features->used_textures[0] = combiner->test_used_textures[0];
    features->used_textures[1] = combiner->test_used_textures[1];
    features->num_inputs = combiner->test_num_inputs;
    features->do_noise = combiner->test_do_noise;
}
