// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdint.h>

typedef volatile struct [[gnu::aligned(4)]] dv_test_status_memory_layout {
    uint32_t status;
} *dv_test_status_t;

enum dv_test_status_code : uint32_t {
    dv_test_status_code_in_test = 0x4354u,
    dv_test_status_code_passed = 0x900du,
    dv_test_status_code_failed = 0xbaadu,
};
