#include "touchscreen_controls_math.h"

#include <stdint.h>

static bool hitbox_contains(const struct TouchControlHitbox *hitbox, int x, int y) {
    if (!hitbox->available || hitbox->width <= 0 || hitbox->height <= 0) return false;
    int64_t dx = (int64_t)x - hitbox->x;
    int64_t dy = (int64_t)y - hitbox->y;
    return dx >= -(int64_t)hitbox->width / 2 && dx < ((int64_t)hitbox->width + 1) / 2 &&
           dy >= -(int64_t)hitbox->height / 2 && dy < ((int64_t)hitbox->height + 1) / 2;
}

int touchscreen_pick_hitbox(const struct TouchControlHitbox *hitboxes,
                            size_t count, int x, int y) {
    if (!hitboxes) return -1;

    /* A pointer region is intentionally broad; it must never steal a button
     * or joystick hit. Within each class, array order remains deterministic. */
    for (int pointer_fallback = 0; pointer_fallback <= 1; ++pointer_fallback) {
        for (size_t i = 0; i < count; ++i) {
            if ((int)hitboxes[i].pointer_fallback != pointer_fallback) continue;
            if (hitbox_contains(&hitboxes[i], x, y)) return (int)i;
        }
    }
    return -1;
}

int touchscreen_clamp_stick_delta(int delta, int axis_extent) {
    if (axis_extent <= 0) return 0;
    int half = axis_extent / 2;
    if (delta < -half) return -half;
    if (delta > half) return half;
    return delta;
}

int touchscreen_axis_from_delta(int delta, int axis_extent, bool invert) {
    if (axis_extent <= 0) return 0;
    int half = axis_extent / 2;
    if (half <= 0) return 0;
    int64_t scaled_delta = delta;
    if (invert) scaled_delta = -scaled_delta;
    if (scaled_delta < -half) scaled_delta = -half;
    if (scaled_delta > half) scaled_delta = half;
    if (scaled_delta >= 0) {
        int value = (int)(scaled_delta * 127 / half);
        return value > 127 ? 127 : value;
    }
    int value = (int)(scaled_delta * 128 / half);
    return value < -128 ? -128 : value;
}
