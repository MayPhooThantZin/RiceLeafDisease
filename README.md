📱 About This Repository

This repository contains a Flutter-based mobile application for rice leaf disease detection, along with ten different trained machine learning models. 
Among these, the second model from the modelv_2 set has been selected for deployment based on its performance.

The training data can be downloaded in https://www.kaggle.com/datasets/loki4514/rice-leaf-diseases-detection?resource=download.
🚀 How to Run the Application

    Install the Application
    Download and install the Flutter application on your mobile device.

    Start the Server
    Before using the application, ensure that the server is running. The server handles image classification requests from the mobile app.

    Using the Application

        When the user launches the app, the camera interface will be displayed along with a button to capture an image.

        Once an image is captured, the application will process it to detect whether a green region (i.e., the leaf) is present.

        If a green region is detected, the image will be sent to the server.

        The server will analyze the image using the selected machine learning model and return the predicted class of rice leaf disease.

        The application will then display the prediction result in a message box, along with the captured image.

