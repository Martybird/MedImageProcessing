# MedImageProcessing

This is a collection of personal software tools for medical image processing, and will be updated timely.

1. MultiLabelFusion.sh

Multi-class label fusion with fuzzy label sampling.

The particular method was used in segmenting midbrian nuclei previously, and it requires the installation of MINC Toolkit (http://bic-mni.github.io).
If you are using the script for your research, please cite the following article:

Y. Xiao, P. Jannin, T. D'Albis, N. Guizard, C. Haegelen, F. Lalys, M. Vérin and D. Louis Collins, 
“Investigation of morphometric variability of subthalamic nucleus, red nucleus, and substantia nigra 
in advanced Parkinson's disease patients using automatic segmentation and PCA-based analysis,” Human Brain Mapping, 
vol.35(9), pp. 4330-4344, 2014.


2. T1-preprocess.sh

Process a single T1 head MRI using MINC toolkit.

The script outputs a skull-stripped MRI in ICBM152 stereotactic space, and the image is processed with N4 field inhomogeneity correction followed by a linear image intensity normalization procedure.


3. How to use register

The instruction explains how to install MINC Toolkit, and use the software package 'register' to view and tag landmarks for medical images. The document uses ultrasound images of the brain to demonstrate the software.
