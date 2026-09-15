
```markdown
# DristhiSetu: AI-Driven Retinal Triage & Explainable Diagnostics

**DristhiSetu** is an intelligent, MATLAB-based clinical triage and diagnostic decision-support system designed to detect Diabetic Retinopathy (DR) from fundus imagery. Built for point-of-care screening in resource-limited environments, it combines computer vision image quality assurance, deep learning grading (ResNet-18), explainable AI (Grad-CAM), and generative clinical report synthesis into an interactive web portal.

---

## 🌟 Key Capabilities

* **Automated Image Quality Assessment (QA):** Evaluates illumination, contrast, and focus metrics before downstream inference to reject poor fundus captures.
* **Deep Learning DR Grading:** Multi-class classification of Diabetic Retinopathy stages (No DR, Mild, Moderate, Severe, Proliferative DR) powered by a fine-tuned ResNet-18 network.
* **Explainable AI (XAI):** Integrated Grad-CAM heatmaps highlight microaneurysms, hemorrhages, and exudate clusters to offer interpretable rationales for clinicians.
* **Agentic Medical Triage:** Bridges model inference with generative clinical assistance (`queryGeminiAgent.m`) to generate contextual clinical observations and triage recommendations.
* **Automated Clinical Reporting:** Generates downloadable diagnostic PDF summaries detailing patient identifiers, classification metrics, and visual saliency maps.
* **Cross-Platform PWA/Web Access:** Packaged via MATLAB Web App Compiler (`.ctf`) for deployment on local web servers or remote access via secure tunnels.

---

## 📂 Project Architecture

```text
├── member1_2_pitch_innovation/   # Clinical workflow design & innovation pitch assets
├── member3_cv_image_quality1/     # Fundus image preprocessing & quality validation pipelines
├── member4_dl_explainability/     # DL model training, evaluation scripts & Grad-CAM routines
├── member5_app_frontend/          # MATLAB App Designer UI source files & export utilities
├── member6_simulink_systems/      # Hardware integration & edge streaming simulation models
├── EyeTriage_Prototype.prj       # MATLAB Project configuration file
└── README.md

```

---

## 🚀 Getting Started

### Prerequisites

* **MATLAB** (R2024a or newer recommended)
* **Toolboxes Required:**
* Deep Learning Toolbox
* Image Processing Toolbox
* Computer Vision Toolbox
* MATLAB Compiler & MATLAB Web App Server (for deployment)



---

### Setup & Local Execution

1. **Clone the Repository:**
```bash
git clone [https://github.com/om-pakhale/DristhiSetu.git](https://github.com/om-pakhale/DristhiSetu.git)
cd DristhiSetu

```


2. **Open the Project in MATLAB:**
* Double-click `EyeTriage_Prototype.prj` or run in the MATLAB Command Window:
```matlab
openProject('EyeTriage_Prototype.prj');

```




3. **Obtain Model Checkpoints:**
* Download the pre-trained weights (`ResNet18_EyePACS.mat`) and place them in:
```text
DR_Project/models/Model1_ResNet18/

```


*(Refer to the repository releases or drive link for shared weights)*.


4. **Launch the Application:**
* Run the main App Designer file:
```matlab
DristhiSetu

```





---

## 🏋️ Model Training

To retrain or fine-tune the classification backbone:

1. Navigate to the deep learning module:
```matlab
cd member4_dl_explainability

```


2. Configure your dataset path inside your training script (`train_model.m`).
3. Execute the script to train the network and save evaluation confusion matrices.

---

## 🌐 Web & Mobile Deployment

To deploy the standalone web interface:

1. Compile the application into a Web App Archive (`.ctf`) using the MATLAB Web App Compiler.
2. Deploy the generated `.ctf` file to the MATLAB Web App Server directory:
```text
C:\ProgramData\MathWorks\webapps\<MATLAB_VERSION>\apps\

```


3. Expose port `9988` securely to mobile devices using Cloudflare Tunnel:
```cmd
cloudflared tunnel --url http://localhost:9988

```


4. Access `https://<your-subdomain>.trycloudflare.com/webapps/home/index.html` in a mobile browser and tap **"Add to Home screen"** to run as a Progressive Web App (PWA).

---

## 🛡️ Clinical Disclaimer

*DristhiSetu is an academic research prototype engineered for clinical decision support and triage assistance. It is not an FDA/CE-certified diagnostic device and should not replace formal ophthalmological evaluation by a licensed medical practitioner.*

---

## 👥 Contributors

* Developed as part of the **EyeTriage Prototype** initiative.

```

Save this as `README.md` in the root of your project directory, commit it, and run `git push origin main` to update your repository landing page.

```
