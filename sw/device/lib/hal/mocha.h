// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha System parameters and Peripheral layout.

#pragma once

#include "hal/clkmgr.h"
#include "hal/dv_test_status.h"
#include "hal/gpio.h"
#include "hal/i2c.h"
#include "hal/plic.h"
#include "hal/rstmgr.h"
#include "hal/spi_device.h"
#include "hal/timer.h"
#include "hal/uart.h"

/* System clock frequency (50 MHz) */
#define SYSCLK_FREQ (50000000u)
/* System clock period in nanoseconds (20 ns) */
#define SYSCLK_NS (20)

static const uintptr_t dram_base = 0x80000000ul;

enum mocha_system_irq : uint32_t {
    mocha_system_irq_spi_device = (1u << 7),
    mocha_system_irq_uart = (1u << 8),
};

/* In order of memory map. */
gpio_t mocha_system_gpio(void);
clkmgr_t mocha_system_clkmgr(void);
rstmgr_t mocha_system_rstmgr(void);
uart_t mocha_system_uart(void);
i2c_t mocha_system_i2c(void);
spi_device_t mocha_system_spi_device(void);
timer_t mocha_system_timer(void);
plic_t mocha_system_plic(void);
dv_test_status_t mocha_system_dv_test_status(void);

void *mocha_system_dram(void);

uint64_t us_to_cycles(uint64_t us);
uint64_t cycles_to_us(uint64_t cycles);
