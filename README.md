# RV64GC CPU Core with SV39 MMU and FPU

A synthesizable, high-performance RV64GC (RISC-V 64-bit General-purpose with Compressed extension) CPU core implemented in Verilog. It includes a compliant IEEE 754 single/double-precision floating-point unit (FPU) and an Sv39 Memory Management Unit (MMU) with Translation Lookaside Buffer (TLB).

## Architecture & Features

- **ISA Support**: RV64GC (RV64I + M + A + F + D + C extensions).
- **Core Pipeline**: Optimized single-cycle execution path with decoupled multiplier/divider to minimize critical path delays.
- **Memory Management Unit (MMU)**: SV39 compliant virtual memory system with a 16-entry TLB (supporting 4KiB pages, 2MiB megapages, and 1GiB gigapages).
- **Floating Point Unit (FPU)**: Full support for single and double precision operations (IEEE 754).
- **Privilege Levels**: Machine-mode (M-mode) and User-mode (U-mode) support with CSR registers.

## Directory Structure

```
Implementation/
├── constraint/      # Timing and physical constraints (200MHz target)
├── rtl/
│   ├── modules/
│   │   ├── rv64gc/  # CPU Core execution unit, registers, decoder
│   │   ├── mmu64/   # SV39 Memory Management Unit & TLB
│   │   └── fpu64/   # Floating Point Unit
│   └── utils/       # Global configuration & header definitions
└── testbench/       # Verification testbenches (CPU, FPU, MMU)
```

## Simulation & Verification

Simulation can be performed using ModelSim:

### 1. Compile & Simulate Core CPU
```bash
vlib work
vmap work work
vlog -sv +incdir+Implementation/rtl/utils +incdir+Implementation/rtl/modules/mmu64 +incdir+Implementation/rtl/modules/fpu64 Implementation/rtl/modules/rv64gc/*.v Implementation/rtl/modules/mmu64/*.v Implementation/rtl/modules/fpu64/*.v Implementation/testbench/tb_rv64gc.sv
vsim -c -do "run -all; quit" tb_rv64gc_cpu
```

### 2. Compile & Simulate MMU
```bash
vlog -sv +incdir+Implementation/rtl/utils +incdir+Implementation/rtl/modules/mmu64 Implementation/rtl/modules/mmu64/*.v Implementation/testbench/tb_mmu64.sv
vsim -c -do "run -all; quit" tb_mmu64_top
```

### 3. Compile & Simulate FPU
```bash
vlog -sv +incdir+Implementation/rtl/modules/fpu64 Implementation/rtl/modules/fpu64/*.v Implementation/testbench/tb_fpu64.sv
vsim -c -do "run -all; quit" tb_fpu64_top
```
