# RV32I Five-Stage Pipeline Processor

This project contains the starter files and build flow for converting the verified Lab 6 RV32I processor into a five-stage pipeline processor. Complete and verify the design according to the Lab 7 manual.

## Project structure

- **text**

  - Makefile

  - README.md

  - libraries/

    - - LEF/

    - - TIMING/

  - mem/

  - rtl/

    - - ALU.v

    - - ALU_decoder.v

    - - Branch_Comp.v

    - - control_unit.v

    - - DMEM.v

    - - IMEM.v

    - - Imm_Gen.v

    - - main_decoder.v

    - - Program_Counter.v

    - - RegisterFile.v

  - scripts/

    - - run_syn.tcl

    - - run_xmsim.tcl

    - - synth_opt.tcl

  - sw/

    - - crt0.s

    - - linker.ld

  - tb/

Directory roles:

- `rtl/`: reusable processor RTL modules from Lab 6.

- `tb/`: destination for the student-written self-checking testbench.

- `sw/`: bare-metal test program, startup code, and linker script.

- `mem/`: instruction and data memory images generated from the software.

- `scripts/`: Xcelium and Genus command scripts.

- `libraries/`: technology files used by synthesis.

The supplied RTL files are divided into two groups.

The following seven modules are verified Lab 6 modules and are reused without changing their module interfaces or internal behavior:

- `text`

- `rtl/ALU.v`

- `rtl/ALU_decoder.v`

- `rtl/Branch_Comp.v`

- `rtl/DMEM.v`

- `rtl/IMEM.v`

- `rtl/Imm_Gen.v`

- `rtl/RegisterFile.v`

The following three files contain the verified Lab 6 baseline logic, but must be updated by the student as required by the Lab 7 manual:

- `text`

- `rtl/Program_Counter.v` - Add PC hold support and redirect-over-stall priority.

- `rtl/main_decoder.v` - Move PCSel resolution to EX and expose class/use flags.

- `rtl/control_unit.v` - Export the class/use flags and declare internal nets.

Use the verified `RISCv_Single_Cycle.v` from your completed Lab 6 project as the starting point for `rtl/RISCv_Pipeline.v`. Partition that design into the IF, ID, EX, MEM, and WB stages as specified in the Lab 7 manual. Do not include both top-level modules in the Lab 7 RTL source list.

The following files are not included and must be created by the student according to the interfaces in the Lab 7 manual:

- `text`

- `rtl/RISCv_Pipeline.v`

- `rtl/IF_ID_reg.v`

- `rtl/ID_EX_reg.v`

- `rtl/EX_MEM_reg.v`

- `rtl/MEM_WB_reg.v`

- `rtl/forward_unit.v`

- `rtl/hazard_detect.v`

- `rtl/Branch_Resolve.v`

- `tb/tb_RISCv_Pipeline.v`

Keep the module names and interfaces specified by the Lab 7 manual.

## Software test source

Keep exactly one test program in `sw/`:

- `sw/test.c` for a C test program; or

- `sw/test.S` for a RISC-V assembly test program.

Do not keep both files at the same time. The Makefile intentionally stops with an error if both are present. The required startup and linker files must retain their standard names:

`text`
sw/crt0.S
sw/linker.ld

The software is compiled for `rv32i` with the `ilp32` ABI. The generated images are:

`text`
mem/imem.hex
mem/dmem_init.hex

Each image contains 256 32-bit hexadecimal words.

## Required tools

The complete flow uses:

- RISC-V GNU toolchain: `riscv32-unknown-elf-gcc`, `objcopy`, `objdump`, `readelf`, and `size`

- Cadence Xcelium

- Cadence Genus

- Standard Linux utilities: `make`, `dd`, and `hexdump`

... (truncated because of tool output limit)