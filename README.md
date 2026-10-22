# MotionMind

MotionMind is a mobile movement-coaching application with on-device pose
inference, a FastAPI service for biomechanics and performance analysis, and a
small web demo for development.

## Project layout

- `android/`, `ios/`, `lib/`, `web/`, and the other platform folders contain the
  Flutter application.
- `backend/` contains the active FastAPI service used by the mobile app.
- `backend/legacy/` preserves the earlier agent, prompt, and ML model pipeline
  without splitting it into a separate project.
- `frontend/` contains the existing browser demo.

## Run the Flutter app

```bash
flutter pub get
flutter run
```

For a connected Android phone, enable USB debugging and run:

```bash
flutter devices
flutter run -d <device-id>
```

## Run the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
PYTHONPATH=. uvicorn app.main:app --host 0.0.0.0 --port 8000
```

When using USB debugging, forward the backend port to the phone with
`adb reverse tcp:8000 tcp:8000`.

## Verification

The Android build uses the bundled MediaPipe pose task and the MotionMind
quality TFLite model. Generated build output, virtual environments, and cache
directories are intentionally ignored by Git.
