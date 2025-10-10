# Digital Design Verification Projects

This repository contains comprehensive SystemVerilog-based verification environments for commonly used digital design modules and communication protocols.

## 📋 Overview

This project demonstrates functional verification of the following modules:
- **FIFO (First-In-First-Out)** - 8-bit synchronous memory buffer with 16-entry depth
- **UART (Universal Asynchronous Receiver-Transmitter)** - Configurable serial communication protocol
- **SPI (Serial Peripheral Interface)** - 12-bit synchronous master-slave communication protocol

All design modules and testbenches are developed using **SystemVerilog** with a layered verification architecture.

## 🏗️ Testbench Architecture

Each verification environment follows a structured, layered testbench methodology consisting of:

- **Transaction Class** - Defines stimulus data packets and control signals
- **Generator** - Creates constrained random test scenarios with configurable transaction counts
- **Driver** - Drives stimulus to the DUT (Design Under Test) via virtual interface
- **Monitor** - Observes and captures DUT input/output responses
- **Scoreboard** - Compares expected vs. actual results and tracks errors
- **Environment** - Encapsulates all verification components and manages communication
- **Test Module** - Top-level testbench with clock generation and DUT instantiation

## 📁 Repository Structure
## 🚀 Module Specifications

### 1. FIFO (First-In-First-Out)

- **Data Width:** 8 bits
- **Depth:** 16 entries
- **Features:** Full and empty flags, synchronous read/write operations
- **Verification:** Random read/write operations with queue-based scoreboard

**Files:**
- **Design:** [`fifo.sv`](fifo.sv) - Contains FIFO module and interface definition
- **Testbench:** [`Testbench.sv`](Testbench.sv) - Complete verification environment with all classes

**Key Features:**
- Circular buffer implementation with read/write pointers
- Status flags for full and empty conditions
- Queue-based golden reference model in scoreboard
- Randomized read/write operation generation

---

### 2. UART (Universal Asynchronous Receiver-Transmitter)

- **Configuration:** Parameterized clock frequency and baud rate
- **Data Width:** 8 bits
- **Default Settings:** 1 MHz clock, 9600 baud rate
- **Features:** Separate transmitter (TX) and receiver (RX) modules with done signals
- **Verification:** Bidirectional data transfer verification with separate TX/RX testing

**Files:**
- **Design:** [`uart_top_verif.sv`](uart_top_verif.sv) - Contains UART TX, RX modules and interface
- **Testbench:** [`TB.sv`](TB.sv) - Complete verification environment

**Key Features:**
- Configurable baud rate generation
- Start and stop bit handling
- Bidirectional communication testing
- Separate clock domains for TX and RX
- Done signals for transaction completion

---

### 3. SPI (Serial Peripheral Interface)

- **Data Width:** 12 bits
- **Architecture:** Master-Slave communication
- **Features:** Configurable SCLK, MOSI data transfer, CS (Chip Select) control
- **Verification:** End-to-end master-slave data integrity verification

**Files:**
- **Design (Master-Slave):** [`spi_master_slave.sv`](spi_master_slave.sv) - Complete master-slave implementation
- **Design (Top):** [`spi_top.sv`](spi_top.sv) - SPI module with interface
- **Testbench:** [`Verilog_tb_masterSlave.sv`](Verilog_tb_masterSlave.sv) - Verification environment

**Key Features:**
- Master-slave architecture with clock generation
- Chip select control logic
- 12-bit serial data transmission
- Configurable serial clock (SCLK) frequency
- State machine-based control

---

