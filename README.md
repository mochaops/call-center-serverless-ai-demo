# 🎧 Call Center Serverless AI Demo

Transform call audio into **transcriptions**, **insights**, and **structured data** using AI and modern **serverless architecture**.  
This project provides a solid foundation for demos, PoCs, and production-ready call-analysis systems powered by AWS and LLMs.

---

## 📚 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
  - [General Architecture Diagram](#general-architecture-diagram)
  - [Optional Step Functions Pipeline](#optional-step-functions-pipeline)
- [Repository Structure](#repository-structure)
- [Installation](#installation)
- [Usage](#usage)
- [Sample Output (JSON)](#sample-output-json)
- [Use Cases](#use-cases)
- [Contributing](#contributing)
- [Limitations](#limitations)
- [License](#license)

---

## 🧠 Overview

This project demonstrates an end-to-end flow that processes call audio files and generates structured intelligence:

- 🔊 **Automatic transcription**
- 🤖 **Insight extraction using LLMs**
- 😃 **Sentiment analysis**
- 📝 **Intelligent summarization**
- 🧩 **Entity extraction**
- 📦 **Structured JSON output**

The system is modular and designed to integrate with:

- AWS Lambda  
- AWS Transcribe / Whisper / Amazon Bedrock  
- AWS Step Functions  
- Amazon S3   

---

## 🏗️ Architecture

Below is the conceptual architecture illustrating the full flow from audio input to AI-generated insights.

### General Architecture Diagram

```mermaid
flowchart TD

    A[📞 Audio Input (S3 Upload / AWS Connect)] --> B[🔊 Lambda - Audio Normalization]

    B --> C[📝 Transcription Engine<br/>AWS Transcribe / Bedrock]

    C --> D[🤖 AI Insights Processor (Lambda + Bedrock)]

    D --> E[📦 Structured Output (JSON)]

    E --> F[(🗄️ DynamoDB / OpenSearch)]
    D --> G[📁 S3 - Store Insights & Transcripts]

    F --> H[📊 Dashboard / Analytics]

## Step Functions Pipeline
```
stateDiagram-v2
    [*] --> UploadAudio
    UploadAudio --> NormalizeAudio
    NormalizeAudio --> TranscribeAudio
    TranscribeAudio --> GenerateInsights
    GenerateInsights --> StoreResults
    StoreResults --> [*]

    state GenerateInsights {
        [*] --> CallLLM
        CallLLM --> ParseResponse
        ParseResponse --> [*]
    }
```