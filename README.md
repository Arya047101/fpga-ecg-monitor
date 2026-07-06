# FPGA-Based Heart Rate Monitor & Arrhythmia Detection

A real-time ECG processing system implemented in **Verilog** on an **FPGA**. The design detects heart rate, identifies abnormal heart rhythms, and displays the results with low latency. It is based on a modified Pan-Tompkins algorithm and was developed for the **Nexys 4 DDR (Artix-7)** FPGA board. 

---

## Features

* Real-time ECG processing
* Heart rate (BPM) calculation
* Arrhythmia detection
* Modular Verilog implementation
* FPGA-based hardware acceleration
* Tested using MIT-BIH ECG data

---

## System Pipeline

```text
ECG Input
    │
    ▼
Bandpass Filter
    │
Derivative Filter
    │
Squaring
    │
Moving Window Integrator
    │
Low Pass Filter
    │
Centered Derivative
    │
Peak Detection
    │
Adaptive Thresholding
    │
RR Interval & BPM
    │
    ▼
Heart Rate + Arrhythmia Flag
```

---

## Project Structure

| Module                   | Purpose                                |
| ------------------------ | -------------------------------------- |
| Bandpass Filter          | Removes unwanted noise                 |
| Derivative Filter        | Highlights QRS slopes                  |
| Squaring                 | Makes peaks easier to detect           |
| Moving Window Integrator | Forms a smooth QRS envelope            |
| Low Pass Filter          | Reduces remaining ripple               |
| Centered Derivative      | Finds peak locations accurately        |
| Peak Detector            | Detects R-peaks                        |
| Adaptive Thresholding    | Rejects false detections               |
| RR Calculator            | Computes BPM and checks for arrhythmia |



---

## Hardware

| Component       | Value                          |
| --------------- | ------------------------------ |
| FPGA            | Nexys 4 DDR (Artix-7 XC7A100T) |
| Clock           | 100 MHz                        |
| ECG Sample Rate | 360 Hz                         |
| Data Format     | 16-bit Fixed Point (Q1.15)     |



---

## Results

| Metric                |   Value |
| --------------------- | ------: |
| Heart Rate            |  73 BPM |
| Detection Sensitivity |     96% |
| Positive Predictivity |     96% |
| Total LUT Usage       |   3.64% |
| Power Consumption     | 0.134 W |



---

## Outputs

* Heart Rate (7-segment display)
* Arrhythmia status (LED)
* Optional ECG waveform display (VGA)



---

## Technologies Used

* Verilog HDL
* Xilinx Vivado
* Nexys 4 DDR FPGA
* MIT-BIH Arrhythmia Database
* Python (data conversion and visualization)

 

---

## Future Improvements

* Support multiple ECG leads
* Live ECG input using an ADC
* ECG waveform display over VGA
* Higher pipeline throughput
* Arrhythmia classification using machine learning



---

## Authors

* Arya Vishukumar Aimanianda
* Partha Sarathi K N

Department of Electronics and Communication Engineering
National Institute of Technology Karnataka

