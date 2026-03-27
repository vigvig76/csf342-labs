# CS F342 – Computer Architecture Lab 7

## Objective
Extend the processor to support control flow, integrate into a single-cycle design, and transition toward pipelined execution with hazard analysis and mitigation.

---

## Task 1: Add Control Instructions

### Instructions to implement
- beq rs1, rs2, imm
- bne rs1, rs2, imm
- jal rd, imm

### Expected design additions
- Branch comparator (rs1 == rs2, rs1 != rs2)
- PC update logic:
  - PC + 4 (default)
  - PC + imm (branch/jump target)
- Control signals:
  - Branch
  - Jump
  - PCSrc

### Notes
For jal:
- rd ← PC + 4
- PC ← PC + imm

---

## Task 2: Single-Cycle Integration

### Requirements
- Keep control logic behavioral (use the `switch` statement)
- Integrate:
  - ALU
  - Register file
  - Data memory
  - Instruction memory
  - Immediate generator
  - Control unit

### Deliverables
- Top-level module named `cpu_SC.dut`

---

## Task 3: Run Example Programs
Assemble these using the online assembler to convert to machine code.  
Manually load the machine code into the IMEM in your testbench.  
Execute and note outputs.  
Complete the table after each program.  
Write the program test benches so that they will output the table below automatically.

### Program 1 (test bench name `tb1.v`)

```
addi x1, x0, 10
addi x2, x0, 20
addi x4, x0, 5
xori x3, x1, 0xFF
addi x3, x3, 1
sub  x5, x4, x1
add  x6, x2, x4
add  x7, x3, x2
```

| Register | Expected Value | Observed Value |
|----------|--------------|----------------|
| x1 |  |   |
| x2 |  |   |
| x3 |  |   |
| x4 |  |   |
| x5 |  |   |
| x6 |  |   |
| x7 |  |   |

---

### Program 2 (test bench name `tb2.v`)

```
addi x1, x0, 10
addi x2, x0, 5
add  x3, x1, x2
sub  x4, x3, x2
lw   x5, 0(x3)
add  x6, x5, x1
sw   x6, 0(x2)
```

| Register | Expected Value | Observed Value |
|----------|--------------|----------------|
| x1 |  |   |
| x2 |  |   |
| x3 |  |   |
| x4 |  |   |
| x5 |  |   |
| x6 |  |   |
| x7 |  |   |

---

### Program 3: Fibonacci (test bench name `tb3.v`)

```
addi x1, x0, 0
addi x2, x0, 1
addi x3, x0, 10

loop:
add  x4, x1, x2
add  x1, x2, x0
add  x2, x4, x0
addi x3, x3, -1
bne  x3, x0, loop
```

| Register | Expected Value | Observed Value |
|----------|--------------|--------------|
| x1 |  |  |
| x2 |  |  |
| x3 |  |  |
| x4 |  |  |

---

## Task 4: Add Pipeline Registers

### IF/ID
- Instruction
- PC

### ID/EX
- PC
- rs1_val, rs2_val
- Immediate
- Destination register
- Control signals:
  - ALUOp
  - ALUSrc
  - MemRead
  - MemWrite
  - RegWrite
  - MemToReg

### EX/MEM
- ALU result
- Store data
- Destination register
- Control signals:
  - MemRead
  - MemWrite
  - RegWrite
  - MemToReg

### MEM/WB
- Memory data
- ALU result
- Destination register
- Control signals:
  - RegWrite
  - MemToReg
  

### Deliverables
- Top-level module named `cpu_pip.dut`

---

## Task 5: Run Programs on Pipelined version
Use the same test benches that you wrote above. Only run with the new cpu module.  
Note the expected and actual outcomes and comment on them.

---

## Task 6: Fix the pipelined CPU
Modify the **assembly programs only without changing the hardware** to fix the issues you observe above.

Program 1:
```

```

Program 2:
```

```

Program 3:
```

```

### Outputs