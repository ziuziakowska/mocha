riscv64-unknown-elf-gcc -march=rv64imc -mabi=lp64 -static -mcmodel=medany -Wall -g -fvisibility=hidden -ffreestanding -c hello_world.c
riscv64-unknown-elf-gcc -march=rv64imc -mabi=lp64 -static -mcmodel=medany -Wall -g -fvisibility=hidden -ffreestanding -c boot.S
riscv64-unknown-elf-ld -nostdlib -Tlink.ld hello_world.o boot.o -o hello_world.elf
