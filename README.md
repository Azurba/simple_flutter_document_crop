# A Simple Automatic Document Cropping in Flutter Using the Canny Edge Detector
## Abstract
This article presents an efficient method for automatic document cropping in mobile and Windows applications, addressing the common user expectation for document scanning. The proposed strategy leverages the multi-stage Canny Edge Detection algorithm to accurately identify document boundaries. To specifically isolate document perimeters from other detected edges, I suggest an approach that assumes the document is roughly centered and systematically scans from the image's outer edges inwards to pinpoint the outermost white pixels, defining the document's bounding box. This information is then used to programmatically crop the original image, delivering a clean, scan-ready output. The article outlines the implementation steps and demonstrates the practical application of computer vision principles to enhance user experience and streamline document management in modern mobile solutions.

## Full Article
https://dev.to/joaopimentag/a-simple-automatic-document-cropping-in-flutter-using-the-canny-edge-detector-17d4

## Generic A4 Document
![image](https://github.com/user-attachments/assets/bd886f38-4f91-4da3-894b-d9d2d60b0f18)
![image](https://github.com/user-attachments/assets/7cf12d9e-4f8d-48cf-9800-470129009b9c)

## Generic Identity Document 
![image](https://github.com/user-attachments/assets/fbe71775-245a-42a9-a20a-f12f0fae5547)
![image](https://github.com/user-attachments/assets/b9ef8c65-398b-40bb-a1e8-8d539a76ba32)

