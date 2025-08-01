

# **Synoptic: Edge-Connected Visual Intelligence \- Project Documentation**

## **1\. Project Overview**

Synoptic is a streamlined edge+cloud platform that enables anyone to deploy vision-based monitoring systems with **zero ML expertise**. The platform connects **ESP32-CAM** devices to a powerful cloud backend featuring the **Moondream Vision-Language Model (VLM)**, allowing users to simply describe what they want to monitor in natural language.  
The core vision of Synoptic is that recent advancements in Vision-Language Models have eliminated the need for custom model training in many monitoring scenarios. Instead of the traditional approach (collect data → label data → train model → test model → deploy), Synoptic allows users to simply:

1. **Connect** an ESP32-CAM device.  
2. **Describe** what they want to monitor in plain language.  
3. **Select** an appropriate inference mode.  
4. **Start monitoring** immediately.

---

## **2\. The Team**

The project is led by two dedicated individuals with complementary expertise in mechanical engineering, machine learning, and industrial applications.

* **David Bühler**: A Master's student in Mechanical Engineering at KIT Karlsruhe with over 10 years of industry experience. His expertise lies in probabilistic measurement technology, automatic visual inspection, and scientific programming. He has been the managing partner of ECRIN GmbH since 2022\.  
* **Joshua Larsch**: A Master's student in Mechanical Engineering at ETH Zürich, specializing in Machine Learning, Probabilistic AI, Image Analysis, and Robotics. He possesses strong programming skills in Python, Java, C\#, C/C++, and Verilog.

---

## **3\. Problem Statement**

Traditional industrial monitoring systems often face significant challenges that Synoptic aims to address:

* **Safety**: Manual monitoring of personal protective equipment (PPE) is often inconsistent and time-consuming.  
* **Process Monitoring**: Critical status changes on machinery and equipment are frequently detected too late, leading to potential damage or downtime.  
* **Quality Control**: Failures in production lines can cause substantial downtime and financial loss.  
* **Access Control**: Effectively monitoring restricted areas across a large facility is a difficult task.

---

## **4\. The Synoptic Solution & Key Features**

Synoptic provides a holistic hardware and software solution to tackle these challenges.

### **Key Features**

* **Zero-Training Approach**: Eliminates the need for data collection and model training, drastically reducing setup time and complexity.  
* **Natural Language Configuration**: Users can configure monitoring tasks simply by describing their needs in plain English (or other supported languages).  
* **Flexible Inference Modes**: The platform offers various processing modes tailored to different monitoring needs.  
* **AI-Assisted Setup**: A chat-based interface guides users through the entire configuration process, from naming the device to testing the inference.  
* **Device Grouping**: Users can organize their devices by location or purpose for better management.  
* **Multi-Language Support**: The application interface is available in multiple languages, with plans to expand further.

### **User Experience Flow**

1. **Account Setup**: Users create an account and log in via the mobile or web application.  
2. **Device Setup**: A new device is added, and its WiFi is configured via a Bluetooth Low Energy (BLE) connection from the mobile app.  
3. **Task Definition**: Using the AI Assistant, the user describes the monitoring task, and the system helps select the appropriate inference mode and settings.  
4. **Testing**: The user can test the system with a live feed from their phone's camera to verify that the setup works as expected.  
5. **Monitoring**: Once deployed, the user receives real-time alerts and can view a monitoring dashboard with the latest data and image captures.

---

## **5\. Technical Architecture**

Synoptic employs a modern, serverless architecture centered around Firebase and Google Cloud Run, ensuring scalability, reliability, and cost-effectiveness.

### **5.1. Flutter Frontend (Web, Android & iOS)**

The user-facing application is built with **Flutter**, allowing for a single codebase to be deployed across web, Android, and iOS platforms. The app is built and deployed using **Codemagic**.

* **Cross-Platform UI**: The UI is designed to be intuitive and consistent across all platforms. Key UI components include a device list, a configuration page for each device, a real-time monitoring dashboard, and the AI-powered assistant chat.  
* **AI-Assisted Setup**: The assistant\_page.dart provides the chat interface where users interact with the backend to configure their devices. This is a central part of the user experience, abstracting away complex settings.  
* **Device Management**: The home\_page.dart serves as the main entry point after login, displaying a list of devices and allowing users to add new ones or manage existing ones. It also handles device grouping.  
* **Device Configuration**: The device\_config\_page.dart allows for manual configuration and provides access to different settings modules, including camera setup and notification settings.  
* **Hardware Interaction (ESP32)**: The esp\_config\_page.dart handles the initial setup of the ESP32-CAM device. It uses Bluetooth (via the flutter\_blue\_plus package) to scan for and connect to the device, sending WiFi credentials to get it online.  
* **Real-time Updates**: The app utilizes Firebase's real-time capabilities to listen for changes in device status, setup stage, and incoming data. The SetupStageManager in lib/utils/setup\_stage\_manager.dart is a good example of this, providing a stream of the current setup progress.  
* **Localization**: The app supports multiple languages using the flutter\_localizations package, with string files located in the lib/l10n/ directory. This is managed by the UserSettings utility.

### **5.2. Firebase Backend**

The backend is built entirely on Firebase, leveraging its suite of services for a robust and scalable serverless architecture. The core logic is contained within Firebase Functions written in Python, as seen in main.py.

* **Authentication**: Firebase Authentication is used for secure user login and registration. The auth.dart file in the frontend interfaces with this service.  
* **Firestore Database**: Firestore is the primary database for storing user data, device configurations, device groups, and inference history. The data model is hierarchical, with devices and device groups nested under each user.  
* **Firebase Storage**: All images captured by the ESP32-CAM devices, as well as generated device icons, are stored in Firebase Storage. The application uses this to display the latest images and for the region selector in notification settings.  
* **Firebase Functions (main.py)**: This is where the core business logic resides. Key functions include:  
  * assistant\_chat: This function is the heart of the AI-assisted setup. It takes the user's natural language input, constructs a prompt for the Anthropic Claude 3.7 Sonnet model, and processes the model's response to either update device settings directly or call other tools (like createDeviceIcon or setClasses). It also manages the conversation history to provide context for the AI.  
  * perform\_inference: This function is called by the frontend for testing purposes. It takes an image path from storage and runs it through the inference pipeline.  
  * receive\_image: This function is the endpoint for the ESP32 devices. It receives an uploaded image, saves it to storage, and if the device is operational, triggers the inference pipeline and notification checks.  
  * device\_heartbeat: This function allows the ESP32 devices to check in periodically, updating their last\_heartbeat and wifi\_signal\_strength.  
  * set\_classes & process\_icon\_creation: These are tool-callable functions used by the assistant\_chat function to perform specific setup tasks.

### **5.3. Inference Pipeline Architecture**

The project implements a sophisticated multi-model inference system designed for both immediate testing and production deployment. The architecture supports multiple Vision-Language Models and includes comprehensive cost tracking and optimization features.

#### **Current Inference Models**

**Primary Model: Moondream Vision-Language Model (VLM)**
- Hosted on **Google Cloud Run** for scalable, on-demand inference
- Fixed cost model: **20 credits per inference call**
- Supports all inference modes: Point Detection, Object Detection, VQA, and Caption
- Optimized for general-purpose computer vision tasks

**Secondary Model: Google Gemini 2.5 Flash**
- Cloud-based API integration via Google's generative AI service
- Dynamic cost model: **0.3 × token_count** for precise usage tracking
- Specialized for complex multi-object detection scenarios
- Enhanced performance for detailed scene analysis

#### **Inference Pipeline Flow**

The system operates through two distinct pathways:

**1. Testing Pipeline (`perform_inference`)**
- **Trigger**: Called from Flutter frontend's camera testing page
- **Purpose**: Allows users to test inference models using phone camera
- **Flow**: User captures image → Upload to Firebase Storage → `perform_inference` function → `inference()` → Model API → Results displayed with overlays
- **Use Case**: Device configuration validation and model testing

**2. Production Pipeline (`receive_image`)**
- **Trigger**: ESP32-CAM devices upload images during normal operation
- **Purpose**: Continuous monitoring and automated inference
- **Flow**: ESP32 captures image → `receive_image` function → Firebase Storage → Device status check → `inference()` → Model API → Results stored → Notifications triggered
- **Conditional Processing**: Only devices with "Operational" status trigger inference

#### **Core Inference Logic**

**Model Selection**: Environment variable `INFERENCE_MODEL` determines routing:
- `"gemini"`: Routes to Gemini inference pipeline
- `"moondream"` (default): Routes to Moondream inference pipeline

**Class-Based Processing**: For Object Detection and Point Detection:
- System iterates through user-defined classes
- Each class gets individual API calls for precise detection
- Results merged into unified response format
- Supports class descriptions for enhanced accuracy

**Flexible Inference Modes**:
- **Point Detection**: Returns normalized coordinates (x, y) of detected features
- **Object Detection**: Returns bounding boxes with class labels and confidence scores
- **VQA (Visual Question Answering)**: Processes natural language queries about images
- **Caption**: Generates descriptive text for entire image

#### **Credit Usage & Cost Management**

**Real-Time Credit Tracking**:
- **User-Level**: Total credits across all devices stored in user document
- **Device-Level**: Individual device usage for granular analytics
- **Firestore Integration**: Automatic updates via `update_credit_usage()` function
- **Frontend Display**: Real-time credit counters in homepage and device settings

**Cost Calculation Models**:
- **Gemini**: Dynamic pricing based on actual token consumption with fallback estimation
- **Moondream**: Fixed 20-credit cost per inference session
- **Error Handling**: Credit tracking failures don't interrupt inference pipeline

#### **Result Processing & Storage**

**Data Pipeline**:
1. **Raw Results**: Complete API responses stored in `inference_results` collection
2. **Metrics Extraction**: Numerical data extracted via `extract_metrics_from_inference()`
3. **Dashboard Storage**: Processed metrics stored in `recent_outputs` for visualization
4. **Notification System**: Results evaluated against user-defined triggers

**Response Standardization**:
- Coordinates normalized to 0-1 range for frontend compatibility
- Bounding boxes converted to 1024×1024 pixel space
- Consistent JSON structure across different models
- Error handling for various API response formats

#### **Future Architecture Enhancements**

**Task-Specific Inference Networks**
The platform is designed to integrate specialized models for improved performance and cost efficiency:

- **YOLO Integration**: High-speed object detection for time-critical applications
  - Reduced latency for real-time monitoring scenarios
  - Lower computational costs for simple detection tasks
  - Specialized training for industrial/manufacturing environments
  
- **Custom Model Pipeline**: Framework for integrating domain-specific models
  - Manufacturing defect detection networks
  - Safety equipment compliance models
  - Process monitoring specialized architectures
  
- **Hybrid Model Selection**: Intelligent routing based on task complexity
  - Simple detection → YOLO models
  - Complex scene analysis → VLM models
  - Natural language queries → Specialized VLMs

**Pre-Inference Assessment System**
To optimize resource usage and reduce unnecessary inference costs:

**Image Similarity Detection**:
- **Threshold-Based Processing**: Only trigger inference when significant scene changes detected
- **Multiple Detection Methods**:
  - Traditional computer vision (histogram comparison, structural similarity)
  - Lightweight neural networks trained for change detection
  - Perceptual hashing for rapid similarity assessment

**Smart Caching Strategy**:
- **Result Replication**: Copy previous inference results when scenes are similar
- **Temporal Awareness**: Factor in time-based changes (lighting, expected movement)
- **Device-Specific Thresholds**: Customizable sensitivity per monitoring scenario

**Implementation Benefits**:
- **Cost Reduction**: Significant savings on inference credits
- **Resource Optimization**: Reduced API calls and processing load
- **Improved Response Times**: Instant results for unchanged scenes
- **Bandwidth Efficiency**: Reduced data transfer for edge devices

#### **Performance Optimization**

**Current Optimizations**:
- **Concurrent Processing**: ThreadPoolExecutor for multi-class detection
- **API Rate Limiting**: Controlled concurrency to prevent service overload
- **Memory Management**: PIL image processing optimized for cloud functions
- **Error Recovery**: Robust handling of API failures and timeouts

**Planned Optimizations**:
- **Edge Inference**: Deploy lightweight models directly on ESP32-CAM devices
- **Batch Processing**: Group multiple images for improved API efficiency
- **Adaptive Quality**: Dynamic image quality adjustment based on detection requirements
- **Regional Processing**: Intelligent cropping to focus on areas of interest

### **5.4. Edge Devices: ESP32-CAM**

The hardware component of the platform consists of ESP32-CAM devices, which are low-cost microcontrollers with an integrated camera and WiFi capabilities.

* **Image Capture**: The ESP32 is responsible for capturing images at configurable intervals or based on motion detection.  
* **Connectivity**: It connects to the internet via WiFi and communicates with the Firebase backend to upload images and send heartbeats.  
* **Initial Configuration**: The initial WiFi setup is done via Bluetooth Low Energy (BLE) from the Flutter mobile app, as handled by the esp\_config\_page.dart. This provides a seamless onboarding experience for the user.

---

## **6\. Codebase Deep Dive**

This section provides a more detailed look at the project's codebase, serving as a guide for future development and maintenance.

### **6.1. Flutter Frontend In-Depth (lib/)**

The Flutter application is structured to separate concerns, with distinct directories for pages, widgets, services, and utilities.

* **Application Entry Point (main.dart)**: This file initializes the application, including Firebase services and notification handling. It also sets up the WidgetTree which routes the user to either the LoginPage or HomePage based on their authentication state. The SplashOverlayManager is used to show a splash screen on app startup and resume.  
* **Authentication Flow (auth.dart, pages/login\_register\_page.dart)**: The Auth class in auth.dart provides a simple interface for interacting with Firebase Authentication. The LoginPage in pages/login\_register\_page.dart uses this class to handle user sign-in and registration.  
* **Main User Interface (pages/home\_page.dart)**: This is the core of the app after login. It displays a list of devices, organized by groups. It uses a StreamBuilder to listen for real-time updates from Firestore. The page allows for adding new devices, renaming groups, and reordering devices within groups.  
* **Device Configuration (pages/device\_config\_page.dart)**: This page provides a high-level overview of a device's settings and serves as a hub to access more detailed configuration pages like the AssistantPage, ESPConfigPage, and NotificationSettingsPage.  
* **AI-Assisted Setup (pages/assistant\_page.dart)**: This page is central to the user experience. It provides a chat interface for users to configure their device using natural language. It handles text input, image attachments, and speech-to-text. The \_sendMessage and \_processAssistantResponse methods are key here, as they communicate with the assistant\_chat Firebase Function. The page also displays ActionMessage widgets to show the progress of backend tasks.  
* **Hardware Setup (pages/esp\_config\_page.dart)**: This page guides the user through connecting their ESP32-CAM device. It uses the flutter\_blue\_plus package to scan for and connect to the device via BLE. Once connected, it sends the user's WiFi credentials to the device, allowing it to connect to the internet.  
* **Camera Testing (pages/camera\_testing\_page.dart)**: This page allows users to test their device's inference model using their phone's camera. It captures an image, sends it to the perform\_inference Firebase Function, and displays the results, including bounding boxes or points overlaid on the image.  
* **Notification Service (services/notification\_service.dart)**: This service handles everything related to push notifications. It initializes Firebase Cloud Messaging (FCM), requests permissions, and manages the FCM token. The getNotificationStatus method is particularly useful for debugging.

### **6.2. Firebase Backend In-Depth (main.py)**

The backend logic is implemented as a set of Python functions deployed to Firebase Functions.

* **assistant\_chat**: This is the most complex function and the core of the AI-powered setup.  
  * **Prompt Engineering**: It dynamically builds a detailed prompt for the Anthropic Claude 3.7 Sonnet model based on the user's message, conversation history, current device settings, and the device's setup stage.  
  * **Tool Calling**: It leverages the model's tool-calling capabilities to perform actions like creating a device icon (createDeviceIcon) or setting classification classes (setClasses). It also uses a batch\_tool to execute multiple actions in parallel.  
  * **Response Handling**: It parses the model's JSON output to extract a message for the user and any settings that need to be changed in Firestore.  
* **perform\_inference & inference**: The perform\_inference function is the HTTP endpoint that receives a request from the frontend's camera testing page. It downloads the specified image from Firebase Storage and passes it to the inference function. The inference function, in turn, calls the Moondream VLM API on Cloud Run and returns the result.  
* **receive\_image**: This function is the endpoint for the ESP32 devices. It handles the incoming image data, saves it to Firebase Storage, and if the device's status is "Operational", it triggers the inference pipeline and subsequent notification checks.  
* **device\_heartbeat**: This function is called periodically by the ESP32 devices. It updates the last\_heartbeat and wifi\_signal\_strength fields for the device in Firestore and returns the latest device settings. This allows for remote configuration updates.  
* **trigger\_action**: This function is called after a successful inference. It checks the device's notification settings and the inference results to determine if a notification should be sent. It supports both count-based and location-based triggers.

### **6.3. ESP32-CAM Firmware In-Depth**

The C++ code for the ESP32-CAM is responsible for the device's core functionality.

* **setup()**: This function runs once when the device boots up. It initializes the serial connection, SPIFFS (for storing configuration), and the camera. It then attempts to load a saved configuration. If a configuration exists, it connects to the specified WiFi network. If not, it starts the BLE server to allow for configuration from the mobile app.  
* **loop()**: This function runs continuously.  
  * If connected to WiFi, it sends a heartbeat to the backend every 20 seconds. It also checks if it's time to capture and send an image based on the configured interval or motion detection.  
  * If not connected to WiFi, it either attempts to reconnect (if it has credentials) or ensures the BLE server is running for configuration.  
* **BLE Configuration (setupBLE, WifiCharCallbacks)**: The device exposes a BLE service with a single characteristic (CHARACTERISTIC\_UUID). When the mobile app writes to this characteristic, the onWrite callback in WifiCharCallbacks is triggered. This callback parses the received string (containing user ID, device ID, SSID, and password), saves it to the configuration file in SPIFFS, and initiates a WiFi connection.  
* **Image Capture & Sending (captureImage, sendImage)**: The captureImage function captures a frame from the camera and encodes it as a Base64 string. The sendImage function then sends this Base64 string in a JSON payload to the receive\_image Firebase Function.  
* **Motion Detection (checkMotion)**: A basic motion detection algorithm is implemented by comparing the average pixel values of consecutive frames. If a significant change is detected, it can trigger an image capture.

---

## **7\. Current Status & Roadmap**

As of May 2025, the Synoptic project has achieved significant milestones:

* **Application**: The mobile app is in the **testing phase** and is available on Android, iOS, and in the browser.  
* **Hardware**: The first **hardware prototypes** are ready for field testing, with a pre-production series made of aluminum currently in development.  
* **Functionality**: The core user flow, from adding a new device to configuring it via the AI chatbot and testing the inference, is functional, as shown in the project presentation.

### **Roadmap**

The future roadmap will focus on refining the existing platform and expanding its capabilities. Key areas of focus will be:

* **Hardware**: Finalizing the design and beginning production of the aluminum-cased devices.  
* **Software**: Optimizing the software for performance and reliability, particularly the inference pipeline and result parsing.  
* **Marketing & Sales**: Developing a go-to-market strategy to reach the target audience.  
* **Legal**: Securing intellectual property through patents and ensuring data privacy compliance.

---

## **8\. Funding & Resources**

The project is seeking funding to accelerate its development and bring the product to market.

* **Funding Goal**: The team is applying for the **EXIST Business Start-up Grant** to cover personnel costs for 12 months and provide funds for prototypes, coaching, and mentoring.  
* **Own Contributions**: The founders have already invested their own resources in building the initial prototypes and have access to production facilities.  
* **Use of Funds**: The funding will be used for:  
  * Hardware development and production.  
  * Software optimization.  
  * Marketing and sales initiatives.  
  * Legal and IP protection.  
* **Partnerships**: The project is supported by a strong network including **KIT**, **ETH Zürich**, and **Fraunhofer IOSB**.

---

## **9\. Potential Challenges & Future Extensions**

### **Challenges**

* **VLM Limitations**: While powerful, general-purpose VLMs like Moondream may not match the performance of custom-trained models for highly specific or nuanced tasks.  
* **Inference Latency**: The cloud-based inference pipeline introduces a small delay, which may be a factor in time-critical applications.  
* **Prompt Engineering**: Finding the most effective natural language prompts to elicit accurate and consistent results from the VLM for various monitoring scenarios will require ongoing refinement.  
* **Edge Connectivity**: Ensuring the system remains robust and reliable in environments with intermittent or poor network connectivity.  
* **Result Parsing**: The process of converting the VLM's text output into structured JSON is a critical and complex part of the system that needs to be highly robust.

### **Future Extensions**

* **Edge Inference**: To reduce latency and improve privacy, smaller, optimized VLMs could be deployed directly on the edge devices.  
* **Custom Prompting**: An advanced feature could allow users to fine-tune the prompts sent to the VLM to achieve better results for their specific use cases.  
* **Multi-Camera Scenes**: The platform could be extended to combine feeds from multiple cameras to provide a more comprehensive view of a scene or process.  
* **Temporal Analysis**: By analyzing sequences of images over time, the system could detect trends, anomalies, or changes that are not apparent in a single frame.  
* **Integration Ecosystem**: An API could be developed to allow Synoptic to connect with other systems (e.g., ERP, SCADA) for automated actions based on detected events.