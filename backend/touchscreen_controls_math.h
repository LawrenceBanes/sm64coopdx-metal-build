#ifndef CONTROLLER_TOUCHSCREEN_MATH_H
#define CONTROLLER_TOUCHSCREEN_MATH_H

#include <stdbool.h>
#include <stddef.h>

struct TouchControlHitbox {
    int x;
    int y;
    int width;
    int height;
    bool available;
    bool pointer_fallback;
};

/* Prefer visible controls to the large free-camera pointer region. */
int touchscreen_pick_hitbox(const struct TouchControlHitbox *hitboxes,
                            size_t count, int x, int y);

int touchscreen_clamp_stick_delta(int delta, int axis_extent);
int touchscreen_axis_from_delta(int delta, int axis_extent, bool invert);

#endif
