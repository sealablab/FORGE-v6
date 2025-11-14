# [Moku Platforms](README.md)

> [!NOTE] This is __offically__ defined inside the moku-models-v4 submodule! 
> 



# Moku Platform Hardware Specifications

**Source**: Official Liquid Instruments datasheets (2024)
**Purpose**: Reference for `moku-models` platform model development

---

## Platform Comparison Table

| Feature | Moku:Go | Moku:Lab | Moku:Pro | Moku:Delta |
|---------|---------|----------|----------|------------|
| **Multi-Instrument Slots** | 2 | 2 | 4 | 3 (standard) or 8 (advanced) |
| **Analog Inputs** | 2 | 2 | 4 | 8 |
| **Analog Outputs** | 2 | 2 | 4 | 8 |
| **ADC Resolution** | 12-bit | 12-bit | 10-bit + 18-bit blended | 14-bit + 20-bit blended |
| **DAC Resolution** | 12-bit | 16-bit | 16-bit | 14-bit |
| **ADC Sample Rate** | 125 MSa/s | 500 MSa/s | 5 GSa/s (1ch) / 1.25 GSa/s (4ch) | 5 GSa/s (all 8 channels) |
| **DAC Sample Rate** | 125 MSa/s | 1 GSa/s | 1.25 GSa/s | 10 GSa/s (with interpolation) |
| **Input Bandwidth** | 30 MHz | 200 MHz | 300/600 MHz (selectable) | 2 GHz |
| **Output Bandwidth** | 20 MHz | 300 MHz | 500 MHz | 2 GHz |
| **Input Impedance** | 1 MΩ (AC/DC coupling) | 50 Ω or 1 MΩ (switchable) | 50 Ω or 1 MΩ (switchable) | 50 Ω or 1 MΩ (switchable) |
| **Output Impedance** | Low impedance | 50 Ω | 50 Ω | 50 Ω |
| **Input Voltage Range** | ±25 V (fixed) | 1 Vpp or 10 Vpp (switchable) | 400 mVpp, 4 Vpp, or 40 Vpp (switchable) | 100 mVpp, 1 Vpp, 10 Vpp, or 40 Vpp (switchable) |
| **Output Voltage Range** | ±5 V | 2 Vpp (into 50 Ω) | ±1 V up to 500 MHz, ±5 V up to 100 MHz | ±500 mV up to 2 GHz, ±5 V up to 100 MHz |
| **Digital I/O** | 16 pins @ 125 MSa/s | N/A (no DIO header) | N/A (no DIO header) | 32 pins (2×16) @ 5 GSa/s |
| **DIO Logic Level** | 3.3 V (5 V tolerant) | N/A | N/A | 3.3 V (5 V tolerant) |
| **FPGA** | Not specified | Xilinx Zynq 7020 | Xilinx Ultrascale+ | Xilinx RFSoC (3rd gen) |
| **Clock Stability** | Not specified | 500 ppb | 0.3 ppm | 1 ppb OCXO |
| **Data Storage** | N/A | SD card | 240 GB SSD | 1 TB SSD |
| **Form Factor** | Portable (1.7 lb) | Benchtop | Benchtop (rack mount) | Benchtop (2U rack) |
| **Connectivity** | USB-C, Wi-Fi, Ethernet (M2) | Wi-Fi, Ethernet, USB | Wi-Fi, Ethernet, USB-C | Ethernet, SFP, QSFP, USB-C |

---
