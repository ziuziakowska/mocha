// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/timer.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void timer_init(timer_t timer)
{
    timer_disable(timer);
    timer_interrupt_enable_set(timer, false);
    uint64_t cycles = us_to_cycles(1u);
    /* configure the timer to tick by one every us */
    timer_cfg0 cfg = {
        .prescale = cycles - 1u,
        .step = 1u,
    };
    volatile_write(timer->cfg0, cfg);
}

bool timer_interrupt_enable_get(timer_t timer)
{
    timer_intr_enable0 intr_enable = volatile_read(timer->intr_enable0);
    return intr_enable.ie;
}

void timer_interrupt_enable_set(timer_t timer, bool enable)
{
    timer_intr_enable0 intr_enable = { .ie = enable };
    volatile_write(timer->intr_enable0, intr_enable);
}

void timer_interrupt_force(timer_t timer)
{
    timer_intr_test0 intr_test = { .t = true };
    volatile_write(timer->intr_test0, intr_test);
}

void timer_interrupt_clear(timer_t timer)
{
    timer_intr_state0 intr_state = { .is = true };
    volatile_write(timer->intr_state0, intr_state);
}

bool timer_interrupt_pending(timer_t timer)
{
    timer_intr_state0 intr_state = volatile_read(timer->intr_state0);
    return intr_state.is;
}

void timer_enable(timer_t timer)
{
    timer_ctrl ctrl = { .active = true };
    volatile_write(timer->ctrl, ctrl);
}

void timer_disable(timer_t timer)
{
    timer_ctrl ctrl = { .active = false };
    volatile_write(timer->ctrl, ctrl);
}

uint64_t timer_value_get_us(timer_t timer)
{
    uint32_t timer_lower, timer_upper, timer_upper_again;
    do {
        /* make sure the lower half of the timer value does
         * not overflow while reading the two halves, see
         * Unprivileged Spec Chapter 7.1 */
        timer_upper = volatile_read(timer->timer_v_upper0);
        timer_lower = volatile_read(timer->timer_v_lower0);
        timer_upper_again = volatile_read(timer->timer_v_upper0);
    } while (timer_upper != timer_upper_again);

    return (((uint64_t)timer_upper) << 32u) | timer_lower;
}

static void timer_compare_set(timer_t timer, uint64_t compare)
{
    uint32_t compare_lower = (uint32_t)compare;
    uint32_t compare_upper = (uint32_t)(compare >> 32u);

    /* write all 1s to the bottom half first, then the top and
     * bottom to not cause a spurious interrupt from writing an
     * intermediate value, see Privileged Spec Chapter 3.2.1 */
    volatile_write(timer->compare_lower0_0, UINT32_MAX);
    volatile_write(timer->compare_upper0_0, compare_upper);
    volatile_write(timer->compare_lower0_0, compare_lower);
}

void timer_schedule_in_us(timer_t timer, uint64_t us)
{
    timer_compare_set(timer, timer_value_get_us(timer) + us);
}

void timer_schedule_in_ms(timer_t timer, uint64_t ms)
{
    timer_schedule_in_us(timer, ms * 1000u);
}

void timer_busy_sleep_us(timer_t timer, uint64_t us)
{
    timer_schedule_in_us(timer, us);
    while (!timer_interrupt_pending(timer)) {
    }
}

void timer_busy_sleep_ms(timer_t timer, uint64_t ms)
{
    timer_busy_sleep_us(timer, ms * 1000u);
}
