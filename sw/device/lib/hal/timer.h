// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/timer.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* initialisation */
void timer_init(timer_t timer);

/* interrupts */
bool timer_interrupt_enable_get(timer_t timer);
void timer_interrupt_enable_set(timer_t timer, bool enable);
void timer_interrupt_force(timer_t timer);
void timer_interrupt_clear(timer_t timer);
bool timer_interrupt_pending(timer_t timer);

void timer_enable(timer_t timer);
void timer_disable(timer_t timer);
uint64_t timer_value_get_us(timer_t timer);
void timer_schedule_in_us(timer_t timer, uint64_t us);
void timer_schedule_in_ms(timer_t timer, uint64_t ms);
void timer_busy_sleep_us(timer_t timer, uint64_t us);
void timer_busy_sleep_ms(timer_t timer, uint64_t ms);
