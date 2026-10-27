# ARINC 429 Receiver (Verilog)

A synthesizable Verilog receiver for **ARINC 429**, the standard digital data bus used between avionics systems on commercial aircraft.

## What it does

It takes a recovered bit stream (bit 1 first) and outputs the decoded fields of each 32-bit word:

| Bits | Field | Notes |
|---|---|---|
| 1–8 | Label | Identifies the parameter. Transmitted MSB first, so the receiver bit-reverses it |
| 9–10 | SDI | Source/destination identifier |
| 11–29 | Data | 19-bit payload |
| 30–31 | SSM | Sign/status matrix |
| 32 | Parity | Odd parity over the whole word |

It also flags:
- **Parity errors** (`parity_ok = 0`)
- **Truncated words** (`length_err`): if an inter-word gap arrives before 32 bits, the partial word is discarded and the receiver resyncs

## Scope

This covers the **digital** side only. It assumes an external line receiver has already converted the bipolar return-to-zero bus voltage into `bit_valid` and `bit_in` strobes and detects the inter-word gap. A full implementation would also need that bit-recovery logic.

## Verification

The self-checking testbench builds ARINC 429 words with known fields, sends them serially, and checks every output:

```
PASS  label 203 normal word
PASS  all-zero data
PASS  all-ones fields
PASS  alternating data
PASS  corrupted bit -> parity error
PASS  truncated word -> length_err
PASS  recovery after error

7 passed, 0 failed
```

## Run it

```bash
iverilog -g2012 -o sim rtl/arinc429_rx.v tb/tb_arinc429_rx.v
vvp sim
gtkwave arinc429_rx.vcd     # optional: view waveforms
```

It also runs on EDA Playground with no install: paste the RTL as the design and the testbench as the testbench.

## Next steps

- Bit recovery from the bipolar RZ signal (HI/LO inputs), supporting high speed (100 kbps) and low speed (12.5 kbps)
- Label filtering, so only selected labels are accepted
- A matching transmitter, with loopback testing
- Synthesis on an FPGA
