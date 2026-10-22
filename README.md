<div align="center">

# MotionMind

### Your movement, understood.

An on-device movement-coaching application that combines Flutter, MediaPipe
pose tracking, TensorFlow Lite quality scoring, and a FastAPI biomechanics
backend.

[![Flutter](https://img.shields.io/badge/Flutter-3.44.1-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.110%2B-009688?logo=fastapi&logoColor=white)](https://fastapi.tiangolo.com/)
[![MediaPipe](https://img.shields.io/badge/MediaPipe-Pose-FF6F00)](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-On--device-FF6F00?logo=tensorflow&logoColor=white)](https://www.tensorflow.org/lite)

</div>

## What is MotionMind?

MotionMind turns a phone camera into a personal movement coach. The mobile
application tracks a person’s pose locally, evaluates movement quality, and
syncs useful telemetry with the backend for biomechanics, performance,
coaching, recommendations, digital-twin, and memory features.

The app is designed to remain useful when the backend is unavailable: core
camera and on-device pose inference run on the phone, while backend analysis is
an additional layer for richer feedback.

## Highlights

- Real-time human pose tracking with MediaPipe Pose Landmarker.
- Lightweight TensorFlow Lite quality scoring on Android.
- Front/rear camera switching and USB or Wi-Fi phone development workflows.
- Responsive Flutter experience for practice, marketplace, coaching, profile,
  and progress screens.
- FastAPI agent routes for vision, biomechanics, performance, coaching,
  recommendations, planning, digital-twin, and session memory.
- Preserved ML/agent pipeline under `backend/legacy/` for compatibility and
  future migration.
- Mock authentication and data providers when Firebase is not configured.

## Architecture

```text
Phone camera
    │
    ├── MediaPipe Pose Landmarker (on device)
    ├── MotionMind quality model (TFLite, on device)
    │
    └── Flutter app ── HTTP ──> FastAPI agent backend
                                  ├── Vision
                                  ├── Biomechanics
                                  ├── Performance
                                  ├── Coach
                                  ├── Recommendation / Planner
                                  ├── Digital Twin
                                  └── Memory
```

## Repository layout

```text
.
├── android/                 # Android host and native MediaPipe/TFLite bridge
├── ios/                     # iOS host and native camera bridge
├── lib/                     # Flutter application code
│   ├── core/                # Theme, routing, services, shared widgets
│   └── features/            # Practice, home, coaching, marketplace, etc.
├── backend/                 # Active FastAPI service used by the app
│   ├── app/                 # API, schemas, and active agent routers
│   ├── tests/               # Active backend tests
│   └── legacy/              # Earlier agents, prompts, and ML models
├── frontend/                # Small browser demo
├── test/                    # Flutter tests
├── web/ linux/ macos/       # Other Flutter targets
├── pubspec.yaml             # Flutter dependencies
└── README.md
```

## Requirements

Install these before starting development:

- Flutter 3.44.1 or a compatible Flutter SDK with Dart 3.12.1+.
- Python 3.10 or newer.
- `adb` / Android platform tools for a physical Android device.
- A USB cable for the simplest phone workflow. Android Studio is optional;
  Flutter and the Android SDK command-line tools are sufficient.

Check the local toolchain:

```bash
flutter doctor
python3 --version
adb version
```

## Quick start

From the repository root:

```bash
flutter pub get
flutter run
```

To build an Android debug APK:

```bash
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk` and build
output is ignored by Git.

## Run on an Android phone over USB

1. Enable **Developer options** and **USB debugging** on the phone.
2. Connect the phone and accept the RSA authorization prompt.
3. Confirm that ADB can see it:

   ```bash
   adb devices
   flutter devices
   ```

4. Start the backend in one terminal:

   ```bash
   cd backend
   python3 -m venv .venv
   source .venv/bin/activate       # Windows: .venv\\Scripts\\activate
   pip install -r requirements.txt
   PYTHONPATH=. uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```

5. In another terminal, forward the backend port through USB and launch the
   app:

   ```bash
   adb reverse tcp:8000 tcp:8000
   flutter run -d <device-id>
   ```

`adb reverse` lets the phone use the default backend URL,
`http://127.0.0.1:8000`, without changing application code.

## Run over Wi-Fi

Keep the computer and phone on the same network, start the backend with
`--host 0.0.0.0`, and launch Flutter with the computer’s LAN address:

```bash
flutter run \
  --dart-define=MOTIONMIND_API_URL=http://<computer-ip>:8000
```

For wireless ADB on Android 11+, use the phone’s **Wireless debugging**
pairing flow. For a previously paired device, the classic development flow is:

```bash
adb tcpip 5555
adb connect <phone-ip>:5555
```

## Backend API

The active service is available at `http://127.0.0.1:8000` and exposes
interactive documentation at `/docs` when running.

| Route | Method | Purpose |
| --- | --- | --- |
| `/` | `GET` | Service health and active agents |
| `/agents/vision` | `POST` | Vision and pose analysis |
| `/agents/biomechanics` | `POST` | Biomechanical metric extraction |
| `/agents/performance` | `POST` | Score and performance evaluation |
| `/agents/coach` | `POST` | Coaching feedback |
| `/agents/recommendation` | `POST` | Training recommendations |
| `/agents/planner` | `POST` | Skill roadmap generation |
| `/agents/twin/{user_id}` | `GET` | Read digital-twin profile |
| `/agents/twin/update` | `POST` | Update digital-twin profile |
| `/agents/memory/store` | `POST` | Store session memory |
| `/agents/memory/history/{user_id}` | `GET` | Read session history |

## On-device models

The Android application bundles the inference assets it needs:

| Asset | Role |
| --- | --- |
| `android/app/src/main/assets/pose_landmarker_lite.task` | MediaPipe body-pose model |
| `android/app/src/main/assets/motionmind_quality.tflite` | Lightweight movement-quality scorer |

The Android native bridge handles camera frame conversion, pose inference, and
the TFLite output tensor. The app can still display local pose state if a
backend request fails.

## Testing and quality checks

Run the active backend tests:

```bash
PYTHONPATH=backend pytest -q backend/tests
```

Run the preserved legacy pipeline tests:

```bash
pytest -q backend/legacy/tests
```

Run Flutter checks when the Flutter SDK is installed:

```bash
flutter analyze
flutter test
```

## Troubleshooting

### `adb devices` is empty

- Confirm the phone is unlocked and USB debugging is enabled.
- Reconnect the cable and choose **File transfer** if prompted.
- Accept the RSA authorization dialog on the phone.
- Restart ADB with `adb kill-server && adb start-server`.

### The app cannot reach the backend over USB

Make sure Uvicorn is running, then run:

```bash
adb reverse --remove tcp:8000
adb reverse tcp:8000 tcp:8000
```

### The app cannot reach the backend over Wi-Fi

Use the computer’s LAN IP, not `127.0.0.1`, and ensure port 8000 is allowed by
the firewall:

```bash
flutter run --dart-define=MOTIONMIND_API_URL=http://<computer-ip>:8000
```

### Firebase is not configured

The application falls back to local mock authentication and data providers
when Firebase is unavailable. Add platform-specific Firebase configuration
only when production authentication or Firestore is required; credentials and
generated secrets should not be committed.

## Storage and generated files

`.dart_tool/`, `build/`, Python virtual environments, test caches, and other
generated files are ignored. Keep dependencies inside the backend `.venv` and
run `flutter clean` when reclaiming Flutter build space.

## Contributing

Keep changes inside the unified root layout, add or update tests for backend
behavior, and run the relevant Flutter or Python checks before opening a pull
request. Do not commit API keys, Firebase credentials, virtual environments,
APK outputs, or model caches.
