# Digit AIpro – Cloud ML & TensorFlow Suite

An end-to-end handwritten digit recognition platform that covers Google Cloud ML APIs, Firebase, Keras CNN/RNN models, hyperparameter tuning and Cloud Shell deployment. Built for the MLCC-ACT2 activity.

## Features

- **Digit Studio** – draw, upload or capture (camera) a digit and get a prediction.
- **Saved Scans** – history of scans stored in Firebase (Firestore) per signed-in user.
- **Cloud APIs** – demos of Google Cloud ML / Gemini-powered APIs.
- **Model Lab** – architecture views, hyperparameter lab, sequential RNN view and a deployment guide.
- **Python Suite** – ready-to-use Keras code snippets and a trained notebook (`public/Digit_AIpro_Trained_Model.ipynb`) you can download.

## Tech Stack

- React 19 + TypeScript, Vite, Tailwind CSS 4
- Express server (`server.ts`) with server-side Gemini calls (`@google/genai`) and an LRU response cache
- Firebase (Auth + Firestore, rules in `firestore.rules`)

## Getting Started

### Prerequisites

- Node.js 20+ (or Bun)
- A Gemini API key
- A Firebase project (config in `firebase-applet-config.json`)

### Setup

```bash
git clone https://github.com/adrish-chowdhury/MLCC-ACT2.git
cd MLCC-ACT2
npm install        # or: bun install
cp .env.example .env
```

Edit `.env`:

```env
GEMINI_API_KEY="your-gemini-api-key"
APP_URL="http://localhost:3000"
```

### Run

```bash
npm run dev        # starts the Express + Vite dev server on http://localhost:3000
```

### Other scripts

| Script | Description |
| --- | --- |
| `npm run build` | Production build with Vite |
| `npm run preview` | Preview the production build |
| `npm run lint` | Type-check with `tsc --noEmit` |
| `npm run clean` | Remove build output |

## Project Structure

```
├── server.ts                 # Express server + Gemini API endpoints
├── firestore.rules           # Firestore security rules
├── public/                   # Static assets, trained notebook
└── src/
    ├── App.tsx               # App shell and tab routing
    ├── components/           # Studio, Saved Scans, Cloud APIs, Model Lab, etc.
    ├── contexts/AuthContext  # Firebase auth state
    ├── data/                 # Python snippets, notebook generator
    ├── utils/                # Digit recognition and weights
    └── firebase.ts           # Firebase initialisation
```

## Credits

Based on [AbdulKaiz-007/Rubikas](https://github.com/AbdulKaiz-007/Rubikas).
