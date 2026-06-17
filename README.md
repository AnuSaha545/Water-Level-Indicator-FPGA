# FPGA-Based Water Level Indicator

## Overview

The FPGA-Based Water Level Indicator is a real-time water level monitoring system developed using Verilog HDL. The system utilizes an ultrasonic sensor to measure the water level in a tank and displays the measured information on an LCD display. The project demonstrates the application of FPGA technology in embedded monitoring and control systems.

Developed as a Semester VI Mini Project, this system provides a reliable and efficient solution for monitoring water levels and can be extended for various industrial and domestic applications.

## Features

* Real-time water level monitoring
* Ultrasonic sensor-based distance measurement
* LCD display interface for output visualization
* FPGA implementation using Verilog HDL
* Modular hardware design
* Accurate and efficient level detection

## Technologies Used

* Verilog HDL
* Xilinx ISE Design Suite
* FPGA Development Board
* Ultrasonic Sensor
* LCD Display

## Project Structure

```text
top.v           - Top-level module
ultrasonic.v    - Ultrasonic sensor interface module
lcd_i2c.v       - LCD display controller module
top.ucf         - FPGA pin constraint file
top.prj         - Project configuration file
WLI_LCD.xise    - Xilinx ISE project file
WLI_LCD.gise    - Xilinx ISE generated project file
```

## Working Principle

1. The ultrasonic sensor transmits an ultrasonic pulse.
2. The reflected echo signal is received and processed by the FPGA.
3. The distance between the sensor and water surface is calculated.
4. The water level is determined based on the measured distance.
5. The calculated water level is displayed on the LCD screen in real time.

## Applications

* Water tank monitoring systems
* Smart irrigation systems
* Industrial liquid level monitoring
* Automated water management solutions
* Reservoir and storage tank monitoring

## Contributors

This project was developed by:

* Anu Saha
* Yashvi Jain
* Dhruv Tare
* Vipaak Gaikwad

## Faculty Mentor

**Prof. Lakshmi Iyer**
