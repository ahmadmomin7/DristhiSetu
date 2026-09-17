# DrishtiSetu AI (दृष्टिसेतु)

### Explainable & Safety-Aware Retinal Diagnostic Copilot for Rural India
**Smart India Hackathon 2026** | **Problem Statement ID:** SIH26038  
**Category:** Software | **Theme:** MedTech / HealthTech / BioTech  
**Team ID:** G91 | **Team Name:** DrishtiSetu

---

## 📌 Overview

**DrishtiSetu AI** is an edge-native, offline-tolerant retinal diagnostic screening copilot designed for Diabetic Retinopathy (DR) triage in resource-limited rural Primary Health Centres (PHCs).

Unlike academic "black-box" models that rely on high-bandwidth cloud APIs and high-end GPUs, DrishtiSetu couples a deep learning classifier with **deterministic clinical safety rules**, **Res-UNet biomarker segmentation**, and an **offline store-and-forward telemedicine cache**. The system runs on standard non-GPU laptops in under 30 seconds per scan.

---

## 🚀 Key Features & Pipeline Architecture

The platform operates across five modular pipelines:

* **1. Deterministic Image Quality Assessment (IQA):** Evaluates focus sharpness (Laplacian variance >= 22.0) and RMS contrast (>= 0.35) on-device. High-quality images pass untouched, borderline scans receive green-channel CLAHE, and poor exposures trigger immediate retake alerts to eliminate patient recall delays.
* **2. Res-UNet Biomarker Segmentation:** A 4-level encoder-decoder network (~7.8M parameters) trained on benchmark datasets (IDRiD, DDR, Messidor-2). It segments 6 retinal structures: optic disc, fovea, blood vessels, microaneurysms, hard exudates, and hemorrhages.
* **3. Severity Staging & Hybrid Safety Interlock:** Predicts ICDR Levels 0–4 via fine-tuned ResNet-18. Hard-coded clinical rules override the neural network to force urgent or emergency specialist referrals whenever foveal threats (<= 500 um) or multi-quadrant hemorrhages are detected, guaranteeing >= 90% sensitivity and >= 85% specificity for referable DR (Level >= 2).
* **4. Dual Explainability & Automated PDF Reporting:** Combines Layer-4 Grad-CAM saliency heatmaps with 4-color lesion segmentation masks and exports an audit-ready single-page A4 clinical diagnostic report (PDF) for rapid physician sign-off.
* **5. Simulink Store-and-Forward Telemedicine:** A discrete-event network queue with a 256 MB local flash buffer guaranteeing zero data loss during rural WAN drops (10–1000 kbps), allowing 1 district specialist to oversee up to 150,000 annual screenings.

---

## 🛠️ Tech Stack

* **Platform & Framework:** MATLAB R2026a, MATLAB App Designer
* **Computer Vision & Deep Learning:** Deep Learning Toolbox, Image Processing Toolbox, ResNet-18, Res-UNet
* **Network & Systems Modeling:** Simulink (Monte Carlo Discrete-Event Telemedicine Buffer Simulation)
* **Frontend UI:** HTML5, CSS3, JavaScript integrated into MATLAB via `uihtml`
* **Datasets Used:** EyePACS, IDRiD, Messidor-2, DDR

---

## 📁 Repository Structure

```text
├── manifests/                      # Dataset splitting manifests (Train/Val/Test)
│   └── Model1/
├── member2_pitch_innovation/       # SIH presentation slides and clinical documentation
├── member3_cv_image_quality1/      # Deterministic IQA, green-channel CLAHE, and preprocessing
├── member4_dl_explainability/      # ResNet-18 classifier, Grad-CAM routines, Res-UNet inference
├── member5_app_frontend/           # MATLAB App Designer GUI (DristhiSetu.m) & CSS/JS UI assets
│   ├── DristhiSetu.m
│   └── generate_clinical_pdf.m
├── member6_simulink_systems/       # Simulink store-and-forward WAN telemetry stress test
│   ├── TelemedicineSync.slx
│   └── simulate_telemedicine_program.m
├── o1_prepare_Model1_data.m        # Multi-dataset ingestion and splitting script
├── o2_train_EyePACS.m              # ResNet-18 fast CPU balanced training pipeline
└── README.md
```
---

## 💻 Installation & Setup

### Prerequisites

* MATLAB R2026a or later installed with:
* Deep Learning Toolbox
* Image Processing Toolbox
* Computer Vision Toolbox
* Simulink



### Clone the Repository

```bash
git clone [https://github.com/om-pakhale/DristhiSetu.git](https://github.com/om-pakhale/DristhiSetu.git)
cd DristhiSetu

```

### Launch the Application

1. Open MATLAB and navigate to the project directory.
2. In the MATLAB Command Window, run:

```matlab
addpath(genpath(pwd));
DristhiSetu

```

3. The dark-themed copilot dashboard will launch. You can attach a retinal fundus scan (`.jpg`, `.png`), enter patient details, review extracted biomarker overlays, and export the A4 clinical diagnostic report.

---

## 📊 Clinical ICDR Staging Reference

| Level | Severity Stage | Clinical Biomarkers Identified | Referral Action |
| --- | --- | --- | --- |
| **Level 0** | Normal | Uniform background, zero high-frequency lesions | Routine Annual Screening |
| **Level 1** | Mild NPDR | Isolated microaneurysms only | 12-Month Monitoring |
| **Level 2** | Moderate NPDR | Multiple microaneurysms, hard exudates, minor hemorrhages | Referable DR (Specialist Review) |
| **Level 3** | Severe NPDR | Blot hemorrhages in all 4 quadrants, significant exudate rings | Urgent Referral (Within 1 Week) |
| **Level 4** | Proliferative DR | Neovascularization, vitreous hemorrhage, foveal encroachment (<= 500 um) | Emergency Referral (Immediate) |

---

## 👥 Team DrishtiSetu (Team ID: G91)

* **Om Narendra Pakhale** – System Architecture, ML Pipeline & MATLAB App Designer Frontend
* **Ahmad Momin** – System Architecture, Agentic AI
* **Gous Bahurupi** – Deep Learning Model, Res-UNet / Segmentation Pipeline
* Built for **Smart India Hackathon 2026**

```

```
