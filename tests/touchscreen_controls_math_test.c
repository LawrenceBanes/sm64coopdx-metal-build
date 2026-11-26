#include <assert.h>
#include <limits.h>
#include <stddef.h>

#include "../backend/touchscreen_controls_math.h"

int main(void) {
    const struct TouchControlHitbox boxes[] = {
        { .x = 300, .y = 170, .width = 800, .height = 800,
          .available = true, .pointer_fallback = true },
        { .x = 300, .y = 170, .width = 100, .height = 100,
          .available = true, .pointer_fallback = false },
        { .x = 500, .y = 170, .width = 100, .height = 100,
          .available = true, .pointer_fallback = false },
    };
    /* The mouse/free-camera hit region overlaps C-buttons but yields to them. */
    assert(touchscreen_pick_hitbox(boxes, 3, 300, 170) == 1);
    assert(touchscreen_pick_hitbox(boxes, 3, 500, 170) == 2);
    /* Separate fingers can own a joystick and a button concurrently. Once a
     * button has a touch owner it is unavailable to a second finger, while
     * releasing the first finger makes only its control available again. */
    struct TouchControlHitbox multitouch[] = {
        { .x = 100, .y = 200, .width = 200, .height = 200,
          .available = true, .pointer_fallback = false }, /* joystick */
        { .x = 500, .y = 200, .width = 100, .height = 100,
          .available = true, .pointer_fallback = false }, /* jump */
    };
    int finger_a_control = touchscreen_pick_hitbox(multitouch, 2, 100, 200);
    assert(finger_a_control == 0);
    multitouch[finger_a_control].available = false;
    int finger_b_control = touchscreen_pick_hitbox(multitouch, 2, 500, 200);
    assert(finger_b_control == 1 && finger_b_control != finger_a_control);
    multitouch[finger_a_control].available = true;
    assert(touchscreen_pick_hitbox(multitouch, 2, 100, 200) == finger_a_control);
    /* If the visible control is already owned, the camera region can receive
     * the new touch instead of making the screen dead. */
    struct TouchControlHitbox unavailable[3];
    for (size_t i = 0; i < 3; ++i) unavailable[i] = boxes[i];
    unavailable[1].available = false;
    unavailable[2].available = false;
    assert(touchscreen_pick_hitbox(unavailable, 3, 300, 170) == 0);
    unavailable[0].available = false;
    assert(touchscreen_pick_hitbox(unavailable, 3, 300, 170) == -1);
    assert(touchscreen_pick_hitbox(NULL, 3, 300, 170) == -1);

    /* Match the original iOS stick's centered signed N64 axis mapping. */
    assert(touchscreen_clamp_stick_delta(0, 200) == 0);
    assert(touchscreen_clamp_stick_delta(-500, 200) == -100);
    assert(touchscreen_clamp_stick_delta(500, 200) == 100);
    assert(touchscreen_axis_from_delta(0, 200, false) == 0);
    assert(touchscreen_axis_from_delta(100, 200, false) == 127);
    assert(touchscreen_axis_from_delta(-100, 200, false) == -128);
    assert(touchscreen_axis_from_delta(100, 200, true) == -128);
    assert(touchscreen_axis_from_delta(INT_MAX, 200, false) == 127);
    assert(touchscreen_axis_from_delta(INT_MIN, 200, true) == 127);
    return 0;
}
