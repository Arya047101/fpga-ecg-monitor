# FPGA-Based-Heart-Rate-Monitoring-and-Arrhythmia-Detection
This project focuses on FPGA-based implementation of a high- performance system designed for real-time QRS complex detection and heart rate analysis. The objective of this work is to design a reliable and resource-efficient hardware architecture for heart rate monitoring. 

<img src = "/Resources/Image1.png"></img>

## Different Modules :
Pre-Processing Stage: 

1. Bandpass Filter : It is used to filter out all the high frequency and low frequency noise while allowing only the required frequency band to be used for processing.
2. Derivative Filter : It is used to detect the high slope regions which is necessary to identify a heart beat.
3. Squaring : It amplifies large signals and attenuates the small signals. It basically amplifies the 
4. Integrator :
5. Low Pass Filter : 

QRS Detection Stage:
1. Centered Derivative :
2. Maximum Peak Detector :
3. Adaptive Thresholding :
4. Amplitude and Time Computation :
5. Heart Rate Calculation :
6. Arrhytmia Detection :
7. Heart Rate Display : 

Bandpass filter 
multiplier versus shift logic and its effect on hardware resource efficiency. how we store numbers 


Derivative Filter 
why are we using causal version of the transfer function and not as it is. 