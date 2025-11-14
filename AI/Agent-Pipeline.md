# [Agent-Pipeline](Agent-Pipeline.md)
This document describes the N-state pipeline that the Agents exist and work inside


## Pipeline description
The first phase of the pipeline is __requirements gathering__ 
The most immediate goal to ascertain: 
Does the user want to create
## A new component 
a **new component** is a small, reusable piece of HDL that can serve as a building-block for more advanced designs. Common component examples:
- N-bit barrrel shifter
- N-bit mux
- N-bit majority approver

Component should have:
@CLAUDE help me out


## A new 'Instrument' 
A new 'instrument' is a FPGA design that 
A) Implements the  [CustomWrapper](https://apis.liquidinstruments.com/mcc/wrapper.html) interface defined b [Liquid Instruments](https://apis.liquidinstruments.com)
B) (Optional) Utilized the Forge Loading System (FLS) 

## Forge Loading System

