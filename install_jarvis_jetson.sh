#!/bin/bash

# JARVIS AI Assistant - Complete Installation Script for Jetson Orin
# Run with: bash install_jarvis_jetson.sh

set -e  # Exit on error

echo "========================================="
echo "JARVIS AI Assistant - Jetson Orin Installation"
echo "========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Jetson
print_status "Checking system..."
if [ ! -f /etc/nv_tegra_release ]; then
    print_warning "This doesn't appear to be a Jetson device. Continue anyway? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install basic dependencies
print_status "Installing basic dependencies..."
sudo apt install -y \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential \
    cmake \
    git \
    wget \
    curl \
    portaudio19-dev \
    libsndfile1 \
    ffmpeg \
    libopenblas-dev \
    liblapack-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libatlas-base-dev \
    libhdf5-dev \
    libhdf5-serial-dev \
    libhdf5-103 \
    libqt5gui5 \
    libqt5core5a \
    libqt5widgets5 \
    libssl-dev \
    python3-pyqt5 \
    python3-pyqt5.qtsvg \
    python3-sip-dev \
    qt5-default \
    qtbase5-dev \
    qtchooser \
    qt5-qmake \
    qtbase5-dev-tools \
    libxcb-xinerama0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xkb1 \
    libxkbcommon-x11-0 \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    mesa-utils

print_success "Basic dependencies installed"

# Set up CUDA environment
print_status "Setting up CUDA environment..."
if ! grep -q "CUDA_HOME" ~/.bashrc; then
    echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    echo 'export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1' >> ~/.bashrc
fi
source ~/.bashrc

print_success "CUDA environment configured"

# Create virtual environment
print_status "Creating Python virtual environment..."
cd ~
python3 -m venv jarvis_env --system-site-packages
source ~/jarvis_env/bin/activate

print_success "Virtual environment created"

# Upgrade pip
print_status "Upgrading pip..."
pip install --upgrade pip setuptools wheel

# Install PyTorch for Jetson
print_status "Installing PyTorch for Jetson..."
cd ~
wget https://developer.download.nvidia.com/compute/redist/jp/v512/pytorch/torch-2.1.0a0+41361538.nv23.06-cp38-cp38-linux_aarch64.whl
pip install torch-2.1.0a0+41361538.nv23.06-cp38-cp38-linux_aarch64.whl

# Install torchvision
print_status "Installing torchvision..."
sudo apt install -y libjpeg-dev zlib1g-dev libpython3-dev libavcodec-dev libavformat-dev libswscale-dev
git clone --branch v0.16.0 https://github.com/pytorch/vision torchvision
cd torchvision
export BUILD_VERSION=0.16.0
python3 setup.py install
cd ~

print_success "PyTorch and torchvision installed"

# Install dlib with CUDA support
print_status "Installing dlib with CUDA support..."
git clone https://github.com/davisking/dlib.git
cd dlib
mkdir build
cd build
cmake .. -DDLIB_USE_CUDA=1 -DUSE_AVX_INSTRUCTIONS=1
cmake --build . --config Release
cd ..
python3 setup.py install --set DLIB_USE_CUDA=1
cd ~

print_success "dlib installed"

# Install face_recognition
print_status "Installing face_recognition..."
pip install face_recognition

# Install other Python packages
print_status "Installing Python packages..."
pip install numpy scipy sounddevice pypdf webrtcvad openwakeword PySide6 PyQt5

# Install Vosk (special handling for ARM64)
print_status "Installing Vosk for ARM64..."
pip install https://github.com/alphacep/vosk-api/releases/download/v0.3.45/vosk-0.3.45-py3-none-linux_aarch64.whl

# Install FAISS with GPU support
print_status "Installing FAISS with GPU support..."
git clone https://github.com/facebookresearch/faiss.git
cd faiss
mkdir build
cd build
cmake -DFAISS_ENABLE_GPU=ON -DCUDAToolkit_ROOT=/usr/local/cuda -DFAISS_ENABLE_PYTHON=ON ..
make -j4
make install
cd ../python
python3 setup.py install
cd ~

print_success "FAISS installed"

# Install Ollama for ARM64
print_status "Installing Ollama for ARM64..."
curl -fsSL https://ollama.com/install.sh | sh

# Wait for Ollama to start
sleep 5

# Download models (choose based on your Jetson's RAM)
print_status "Downloading LLM models..."
print_warning "Choose a model based on your Jetson's RAM:"
echo "1) tinyllama (smallest, fastest)"
echo "2) phi:2.7b (good balance)"
echo "3) mistral:7b (largest, might be slow)"
echo "4) Skip for now"
read -p "Enter choice [1-4]: " model_choice

case $model_choice in
    1)
        ollama pull tinyllama
        echo "tinyllama" > ~/jarvis_default_model.txt
        ;;
    2)
        ollama pull phi:2.7b
        echo "phi:2.7b" > ~/jarvis_default_model.txt
        ;;
    3)
        ollama pull mistral:7b
        echo "mistral:7b" > ~/jarvis_default_model.txt
        ;;
    *)
        echo "Skipping model download"
        echo "tinyllama" > ~/jarvis_default_model.txt
        ;;
esac

# Download Vosk model
print_status "Downloading Vosk model..."
mkdir -p ~/jarvis_models
cd ~/jarvis_models
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip -o vosk-model-small-en-us-0.15.zip
cd ~

print_success "Vosk model downloaded"

# Create application directory
print_status "Creating application directory..."
mkdir -p ~/jarvis_app
cd ~/jarvis_app

# Create the JARVIS Python script
print_status "Creating JARVIS Python script..."
cat > jarvis_jetson.py << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# JARVIS AI Assistant - Optimized for Jetson Orin
# Save as: ~/jarvis_app/jarvis_jetson.py

import os
import sys
import json
import time
import threading
import numpy as np
from pathlib import Path

# Jetson optimizations
os.environ['OMP_NUM_THREADS'] = '4'
os.environ['OPENBLAS_NUM_THREADS'] = '4'
os.environ['MKL_NUM_THREADS'] = '4'
os.environ['VECLIB_MAXIMUM_THREADS'] = '4'
os.environ['NUMEXPR_NUM_THREADS'] = '4'

import torch
if torch.cuda.is_available():
    torch.backends.cudnn.benchmark = True
    torch.backends.cudnn.enabled = True
    print(f"CUDA available: {torch.cuda.get_device_name(0)}")
else:
    print("CUDA not available, using CPU")

# PySide6 imports
from PySide6.QtCore import (
    Qt, QObject, QThread, QTimer, QSize, Signal, Slot, 
    QSignalBlocker, QMetaObject
)
from PySide6.QtGui import QColor, QPainter, QPen, QImage, QPixmap, QTextCursor, QRadialGradient
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel, QPushButton, QTextEdit,
    QPlainTextEdit, QVBoxLayout, QHBoxLayout, QFrame, QSizePolicy,
    QProgressBar, QCheckBox, QComboBox, QMessageBox, QFileDialog,
    QLineEdit, QTabWidget, QListWidget, QListWidgetItem, QSpinBox
)

# Other imports
import cv2
import sounddevice as sd
from pypdf import PdfReader
import face_recognition
import sqlite3
import subprocess
import tempfile
import wave
import re

# ========== Configuration ==========
APP_TITLE = "JARVIS AI Assistant - Jetson Edition"
HOME_DIR = str(Path.home())
APP_SUPPORT_DIR = Path(HOME_DIR) / "jarvis_app" / "data"
DATA_DIR = APP_SUPPORT_DIR / "data"
MODELS_DIR = APP_SUPPORT_DIR / "models"
DB_PATH = DATA_DIR / "assistant.sqlite3"
CONFIG_PATH = DATA_DIR / "config.json"

# Create directories
for p in [APP_SUPPORT_DIR, DATA_DIR, MODELS_DIR]:
    p.mkdir(parents=True, exist_ok=True)

# Colors
BG = "#0a0f1a"
PANEL = "#141b2b"
PANEL_2 = "#1e2740"
PANEL_3 = "#2a3457"
TEXT = "#e8eef7"
TEXT_DIM = "#8a9bb5"
ACCENT = "#3d7eff"
ACCENT_2 = "#5c9eff"
GOOD = "#4caf92"
WARN = "#ffb347"
BAD = "#ff6b6b"

# Audio settings
SAMPLE_RATE = 16000
AUDIO_BLOCK_MS = 10
AUDIO_BLOCK_SAMPLES = int(SAMPLE_RATE * AUDIO_BLOCK_MS / 1000)
AUDIO_BLOCK_BYTES = AUDIO_BLOCK_SAMPLES * 2

OLLAMA_HOST = "127.0.0.1"
OLLAMA_PORT = 11434

# ========== Simplified DB Class ==========
class DB:
    def __init__(self, path):
        self.conn = sqlite3.connect(str(path), check_same_thread=False)
        self.conn.row_factory = sqlite3.Row
        self.init()
    
    def init(self):
        cur = self.conn.cursor()
        cur.executescript("""
            CREATE TABLE IF NOT EXISTS students(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                face_encoding BLOB NULL,
                created_at REAL NOT NULL
            );
            CREATE TABLE IF NOT EXISTS logs(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                level TEXT NOT NULL,
                message TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS interactions(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                student_id INTEGER NULL,
                user_text TEXT NOT NULL,
                assistant_text TEXT NOT NULL
            );
        """)
        self.conn.commit()
    
    def close(self):
        self.conn.close()
    
    def add_student(self, name):
        cur = self.conn.cursor()
        cur.execute(
            "INSERT INTO students(name, created_at) VALUES(?, ?)",
            (name.strip(), time.time())
        )
        self.conn.commit()
        return cur.lastrowid
    
    def list_students(self):
        return list(self.conn.execute(
            "SELECT id, name FROM students ORDER BY name ASC"
        ))
    
    def set_student_face_encoding(self, student_id, encoding):
        blob = None if encoding is None else np.asarray(encoding, dtype=np.float32).tobytes()
        self.conn.execute(
            "UPDATE students SET face_encoding=? WHERE id=?",
            (blob, student_id)
        )
        self.conn.commit()
    
    def get_all_face_encodings(self):
        rows = self.conn.execute(
            "SELECT id, name, face_encoding FROM students WHERE face_encoding IS NOT NULL"
        ).fetchall()
        out = []
        for r in rows:
            out.append((
                int(r["id"]), 
                str(r["name"]), 
                np.frombuffer(r["face_encoding"], dtype=np.float32)
            ))
        return out

# ========== Audio Classes ==========
class AudioRingBuffer:
    def __init__(self, capacity_seconds=8.0):
        self.capacity_samples = int(capacity_seconds * SAMPLE_RATE)
        self.buf = np.zeros(self.capacity_samples, dtype=np.int16)
        self.write_pos = 0
        self.lock = threading.Lock()
    
    def push_int16(self, samples):
        with self.lock:
            n = len(samples)
            end = self.write_pos + n
            if end <= self.capacity_samples:
                self.buf[self.write_pos:end] = samples
            else:
                first = self.capacity_samples - self.write_pos
                self.buf[self.write_pos:] = samples[:first]
                self.buf[:n - first] = samples[first:]
            self.write_pos = (self.write_pos + n) % self.capacity_samples
    
    def pull_since(self, last_pos, max_samples):
        with self.lock:
            cur = self.write_pos
            if cur == last_pos:
                return b"", cur
            
            if cur > last_pos:
                avail = cur - last_pos
                take = min(avail, max_samples)
                out = self.buf[last_pos:last_pos + take].copy()
                return out.tobytes(), (last_pos + take) % self.capacity_samples
            
            avail = (self.capacity_samples - last_pos) + cur
            take = min(avail, max_samples)
            first_take = min(take, self.capacity_samples - last_pos)
            parts = [self.buf[last_pos:last_pos + first_take].copy()]
            remain = take - first_take
            if remain > 0:
                parts.append(self.buf[:remain].copy())
            out = np.concatenate(parts) if len(parts) > 1 else parts[0]
            return out.tobytes(), (last_pos + take) % self.capacity_samples

# ========== Vosk STT (simplified) ==========
try:
    from vosk import Model, KaldiRecognizer
    VOSK_AVAILABLE = True
except:
    VOSK_AVAILABLE = False
    print("Vosk not available")

class VoskSTT:
    def __init__(self, model_path):
        if not VOSK_AVAILABLE:
            raise RuntimeError("Vosk not installed")
        self.model = Model(str(model_path))
        self.rec = KaldiRecognizer(self.model, SAMPLE_RATE)
        self.rec.SetWords(False)
        self._final = ""
    
    def reset(self):
        self.rec.Reset()
        self._final = ""
    
    def accept_audio(self, pcm_bytes):
        if self.rec.AcceptWaveform(pcm_bytes):
            self._final = json.loads(self.rec.Result()).get("text", "").strip()
    
    def get_text(self):
        if not self._final:
            self._final = json.loads(self.rec.FinalResult()).get("text", "").strip()
        return self._final

# ========== Ollama Client ==========
import http.client

class OllamaClient:
    def __init__(self, host, port, timeout=30.0):
        self.host = host
        self.port = port
        self.timeout = timeout
    
    def list_models(self):
        try:
            conn = http.client.HTTPConnection(self.host, self.port, timeout=self.timeout)
            conn.request("GET", "/api/tags")
            resp = conn.getresponse()
            data = json.loads(resp.read().decode())
            conn.close()
            return [m.get("name") for m in data.get("models", []) if m.get("name")]
        except:
            return []
    
    def generate(self, model, prompt, options, cancel_event, on_chunk):
        body = json.dumps({
            "model": model,
            "prompt": prompt,
            "stream": True,
            "options": options
        }).encode()
        
        conn = http.client.HTTPConnection(self.host, self.port, timeout=self.timeout)
        conn.request("POST", "/api/generate", body=body, headers={"Content-Type": "application/json"})
        resp = conn.getresponse()
        
        collected = []
        buf = b""
        
        while not cancel_event.is_set():
            chunk = resp.read(4096)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                if line:
                    try:
                        obj = json.loads(line)
                        text = obj.get("response", "")
                        if text:
                            collected.append(text)
                            on_chunk("".join(collected))
                        if obj.get("done"):
                            break
                    except:
                        continue
        
        conn.close()
        return "".join(collected)

# ========== Camera Worker ==========
class CameraWorker(QObject):
    frame = Signal(QImage)
    face_present = Signal(bool)
    face_identified = Signal(str)
    
    def __init__(self, db):
        super().__init__()
        self.db = db
        self.running = False
        self.cap = None
        self.known_encodings = []
        self.known_names = []
        self.face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
    
    @Slot()
    def start(self):
        self.running = True
        self.reload_faces()
        self.cap = cv2.VideoCapture(0)
        if self.cap.isOpened():
            self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
            self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
            self.cap.set(cv2.CAP_PROP_FPS, 15)
        self.loop()
    
    @Slot()
    def stop(self):
        self.running = False
        if self.cap:
            self.cap.release()
    
    def reload_faces(self):
        self.known_encodings = []
        self.known_names = []
        for sid, name, enc in self.db.get_all_face_encodings():
            self.known_encodings.append(enc)
            self.known_names.append(name)
    
    def loop(self):
        last_recog = 0
        while self.running:
            if not self.cap or not self.cap.isOpened():
                time.sleep(0.1)
                continue
            
            ret, frame = self.cap.read()
            if not ret:
                time.sleep(0.03)
                continue
            
            # Face detection
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)
            present = len(faces) > 0
            self.face_present.emit(present)
            
            # Face recognition
            if present and self.known_encodings and (time.time() - last_recog) > 1:
                last_recog = time.time()
                small = cv2.resize(frame, (0,0), fx=0.25, fy=0.25)
                rgb_small = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
                locs = face_recognition.face_locations(rgb_small)
                encs = face_recognition.face_encodings(rgb_small, locs)
                
                if encs:
                    dists = face_recognition.face_distance(self.known_encodings, encs[0])
                    best = np.argmin(dists)
                    if dists[best] < 0.48:
                        self.face_identified.emit(self.known_names[best])
            
            # Convert to QImage
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            h, w, ch = rgb.shape
            qimg = QImage(rgb.data, w, h, ch * w, QImage.Format_RGB888)
            self.frame.emit(qimg)
            
            time.sleep(1/20)

# ========== Mode Enum ==========
from enum import Enum, auto
class Mode(Enum):
    IDLE = auto()
    ARMED = auto()
    LISTENING = auto()
    THINKING = auto()
    SPEAKING = auto()
    ERROR = auto()

# ========== Orchestrator ==========
class Orchestrator(QObject):
    status_changed = Signal(str, str)
    volume_changed = Signal(int)
    transcript_changed = Signal(str)
    reply_changed = Signal(str)
    face_changed = Signal(bool)
    student_list_changed = Signal(list)
    frame_ready = Signal(QImage)
    
    def __init__(self, cfg, db):
        super().__init__()
        self.cfg = cfg
        self.db = db
        self.mode = Mode.IDLE
        self.current_student = None
        self.current_student_name = ""
        self.audio_rb = AudioRingBuffer()
        self.audio_pos = 0
        self.stream = None
        self.stt = None
        self.tts_process = None
        self.cancel_event = threading.Event()
        self.conversation_history = []
        self.max_history = 10
        
        # Load config
        with open(CONFIG_PATH) as f:
            self.config = json.load(f)
        
        # Init STT
        model_path = self.config.get("vosk_model_path", "~/jarvis_models/vosk-model-small-en-us-0.15")
        model_path = os.path.expanduser(model_path)
        if os.path.exists(model_path):
            try:
                self.stt = VoskSTT(model_path)
            except:
                print("Failed to load Vosk model")
        
        # Ollama client
        self.ollama = OllamaClient(OLLAMA_HOST, OLLAMA_PORT)
        
        # Timer
        self.timer = QTimer()
        self.timer.setInterval(20)
        self.timer.timeout.connect(self.on_tick)
    
    @Slot()
    def start(self):
        self.start_audio()
        self.timer.start()
        self.set_mode(Mode.ARMED, "Ready")
    
    @Slot()
    def stop(self):
        self.timer.stop()
        self.stop_audio()
        self.set_mode(Mode.IDLE, "Stopped")
    
    def start_audio(self):
        try:
            def callback(indata, frames, time, status):
                mono = indata[:, 0].astype(np.int16)
                self.audio_rb.push_int16(mono)
            
            self.stream = sd.InputStream(
                samplerate=SAMPLE_RATE,
                blocksize=AUDIO_BLOCK_SAMPLES,
                dtype="int16",
                channels=1,
                callback=callback
            )
            self.stream.start()
        except Exception as e:
            print(f"Audio error: {e}")
    
    def stop_audio(self):
        if self.stream:
            self.stream.stop()
            self.stream.close()
    
    def set_mode(self, mode, status):
        self.mode = mode
        self.status_changed.emit(mode.name, status)
    
    @Slot()
    def begin_listening(self):
        if self.mode in [Mode.THINKING, Mode.SPEAKING]:
            self.cancel_event.set()
            self.cancel_event.clear()
        
        if self.stt:
            self.stt.reset()
            self.set_mode(Mode.LISTENING, "Listening...")
        else:
            self.set_mode(Mode.ERROR, "STT unavailable")
    
    @Slot()
    def stop_all(self):
        self.cancel_event.set()
        self.cancel_event.clear()
        self.set_mode(Mode.ARMED, "Stopped")
    
    def on_tick(self):
        # Get audio
        data, self.audio_pos = self.audio_rb.pull_since(self.audio_pos, 4096)
        
        if data and self.mode == Mode.LISTENING and self.stt:
            self.stt.accept_audio(data)
            # Check if speech ended (simplified - just use timeout)
            if time.time() - getattr(self, 'listen_start', time.time()) > 3:
                self.finalize_listening()
        elif not hasattr(self, 'listen_start'):
            self.listen_start = time.time()
    
    def finalize_listening(self):
        if not self.stt:
            return
        
        text = self.stt.get_text()
        if len(text) < 2:
            self.set_mode(Mode.ARMED, "No speech detected")
            return
        
        self.transcript_changed.emit(text)
        self.set_mode(Mode.THINKING, "Thinking...")
        self.generate_response(text)
    
    def generate_response(self, user_text):
        def worker():
            # Build prompt with history
            name = self.current_student_name or "friend"
            prompt = f"You are JARVIS, a friendly AI assistant talking to {name}. Be warm and conversational.\n\n"
            
            if self.conversation_history:
                prompt += "Previous conversation:\n"
                for u, a in self.conversation_history[-self.max_history:]:
                    prompt += f"User: {u}\nJARVIS: {a}\n"
                prompt += "\n"
            
            prompt += f"{name}: {user_text}\nJARVIS:"
            
            # Generate
            collected = []
            def on_chunk(text):
                nonlocal collected
                self.reply_changed.emit(text)
            
            try:
                model = self.config.get("llm_model", "tinyllama")
                options = {
                    "num_predict": 256,
                    "temperature": 0.8,
                    "top_p": 0.9
                }
                answer = self.ollama.generate(model, prompt, options, self.cancel_event, on_chunk)
                
                # Save to history
                if answer:
                    self.conversation_history.append((user_text, answer))
                    if len(self.conversation_history) > self.max_history:
                        self.conversation_history.pop(0)
            
            except Exception as e:
                self.reply_changed.emit(f"Error: {e}")
            
            self.set_mode(Mode.ARMED, "Ready")
        
        thread = threading.Thread(target=worker)
        thread.daemon = True
        thread.start()
    
    @Slot(bool)
    def on_face_present(self, present):
        self.face_changed.emit(present)
    
    @Slot(str)
    def on_face_identified(self, name):
        self.current_student_name = name
        # Find student ID
        for sid, sname in self.db.list_students():
            if sname == name:
                self.current_student = sid
                break
        self.reply_changed.emit(f"Welcome back, {name}!")
    
    @Slot(QImage)
    def on_frame(self, img):
        self.frame_ready.emit(img)
    
    def refresh_students(self):
        students = self.db.list_students()
        self.student_list_changed.emit([(s["id"], s["name"], False) for s in students])
    
    def add_student(self, name):
        self.db.add_student(name)
        self.refresh_students()
    
    def select_student(self, student_id):
        for sid, name in self.db.list_students():
            if sid == student_id:
                self.current_student = sid
                self.current_student_name = name
                self.conversation_history.clear()
                break

# ========== Avatar Widget ==========
class AvatarWidget(QWidget):
    def __init__(self):
        super().__init__()
        self.phase = 0
        self.speaking = False
        self.mode = "IDLE"
        self.timer = QTimer()
        self.timer.timeout.connect(self.tick)
        self.timer.start(50)
    
    def tick(self):
        self.phase += 0.1
        self.update()
    
    @Slot(str, str)
    def on_status(self, mode, _):
        self.mode = mode
        self.speaking = (mode == "SPEAKING")
    
    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        
        w, h = self.width(), self.height()
        cx, cy = w//2, h//2
        radius = min(w, h) * 0.3
        
        # Colors
        if self.mode == "LISTENING":
            color = QColor(61, 126, 255)
        elif self.mode == "SPEAKING":
            color = QColor(92, 158, 255)
        elif self.mode == "THINKING":
            color = QColor(80, 140, 255)
        else:
            color = QColor(41, 98, 255)
        
        # Draw rings
        for i in range(3):
            alpha = 50 - i*15
            r = radius + i*20 + (10 if self.speaking else 0)
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(color.red(), color.green(), color.blue(), alpha))
            p.drawEllipse(cx - r, cy - r, r*2, r*2)
        
        # Core
        p.setBrush(color)
        p.setPen(Qt.NoPen)
        p.drawEllipse(cx - radius, cy - radius, radius*2, radius*2)
        
        # Glint
        p.setBrush(QColor(255, 255, 255, 100))
        p.drawEllipse(cx - radius//2, cy - radius//2, radius, radius)

# ========== Camera Widget ==========
class CameraWidget(QLabel):
    def __init__(self):
        super().__init__()
        self.setAlignment(Qt.AlignCenter)
        self.setMinimumSize(320, 200)
        self.setMaximumSize(320, 200)
        self.setStyleSheet("background: #1e2740; border-radius: 8px; border: 2px solid #3d7eff;")
    
    @Slot(QImage)
    def update_frame(self, image):
        pixmap = QPixmap.fromImage(image).scaled(
            self.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation
        )
        self.setPixmap(pixmap)

# ========== Main Window ==========
class MainWindow(QMainWindow):
    def __init__(self, db, orch, cam_worker):
        super().__init__()
        self.db = db
        self.orch = orch
        self.cam_worker = cam_worker
        
        self.setWindowTitle(APP_TITLE)
        self.resize(1200, 800)
        
        # Central widget
        central = QWidget()
        self.setCentralWidget(central)
        layout = QHBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        
        # Sidebar
        self.sidebar = QFrame()
        self.sidebar.setFixedWidth(280)
        self.sidebar.setStyleSheet(f"background: {PANEL}; border-right: 1px solid {PANEL_3};")
        sidebar_layout = QVBoxLayout(self.sidebar)
        
        # Sidebar toggle
        toggle_row = QHBoxLayout()
        self.toggle_btn = QPushButton("☰")
        self.toggle_btn.setFixedSize(36, 36)
        self.toggle_btn.clicked.connect(self.toggle_sidebar)
        toggle_row.addWidget(self.toggle_btn)
        toggle_row.addStretch()
        sidebar_layout.addLayout(toggle_row)
        
        # Students section
        sidebar_layout.addWidget(QLabel("Students"))
        self.student_list = QListWidget()
        self.student_list.itemClicked.connect(self.on_student_selected)
        sidebar_layout.addWidget(self.student_list)
        
        # Add student
        add_row = QHBoxLayout()
        self.student_name = QLineEdit()
        self.student_name.setPlaceholderText("Name")
        self.add_btn = QPushButton("+")
        self.add_btn.setFixedSize(36, 36)
        self.add_btn.clicked.connect(self.add_student)
        add_row.addWidget(self.student_name)
        add_row.addWidget(self.add_btn)
        sidebar_layout.addLayout(add_row)
        
        # Capture button
        self.capture_btn = QPushButton("📸 Capture Face")
        self.capture_btn.clicked.connect(self.capture_face)
        self.capture_btn.setEnabled(False)
        sidebar_layout.addWidget(self.capture_btn)
        
        self.capture_status = QLabel("")
        sidebar_layout.addWidget(self.capture_status)
        
        sidebar_layout.addStretch()
        
        # Main content
        self.content = QWidget()
        content_layout = QVBoxLayout(self.content)
        content_layout.setContentsMargins(20, 20, 20, 20)
        
        # Status bar
        status_row = QHBoxLayout()
        self.status_chip = QLabel("ARMED")
        self.status_chip.setStyleSheet(f"background: {PANEL_3}; border-radius: 14px; padding: 6px 16px; color: {GOOD};")
        status_row.addWidget(self.status_chip)
        
        self.face_chip = QLabel("👤 No face")
        self.face_chip.setStyleSheet(f"background: {PANEL_3}; border-radius: 14px; padding: 6px 16px;")
        status_row.addWidget(self.face_chip)
        status_row.addStretch()
        content_layout.addLayout(status_row)
        
        # Avatar
        self.avatar = AvatarWidget()
        self.avatar.setMinimumHeight(300)
        content_layout.addWidget(self.avatar, 1)
        
        # Camera overlay
        self.camera = CameraWidget()
        self.camera.move(20, self.avatar.height() - 220)
        self.camera.setParent(self.avatar)
        
        # Chat area
        chat_frame = QFrame()
        chat_frame.setStyleSheet(f"background: {PANEL}; border-radius: 12px;")
        chat_layout = QVBoxLayout(chat_frame)
        
        self.transcript = QTextEdit()
        self.transcript.setReadOnly(True)
        self.transcript.setMaximumHeight(120)
        chat_layout.addWidget(QLabel("You:"))
        chat_layout.addWidget(self.transcript)
        
        self.response = QTextEdit()
        self.response.setReadOnly(True)
        self.response.setMaximumHeight(120)
        chat_layout.addWidget(QLabel("JARVIS:"))
        chat_layout.addWidget(self.response)
        
        # Controls
        control_row = QHBoxLayout()
        self.listen_btn = QPushButton("🎤 Listen")
        self.listen_btn.clicked.connect(self.orch.begin_listening)
        self.stop_btn = QPushButton("⏹ Stop")
        self.stop_btn.clicked.connect(self.orch.stop_all)
        self.mic_bar = QProgressBar()
        self.mic_bar.setRange(0, 2500)
        self.mic_bar.setTextVisible(False)
        self.mic_bar.setFixedHeight(8)
        
        control_row.addWidget(self.listen_btn)
        control_row.addWidget(self.stop_btn)
        control_row.addWidget(self.mic_bar, 1)
        chat_layout.addLayout(control_row)
        
        content_layout.addWidget(chat_frame)
        
        # Assemble
        layout.addWidget(self.sidebar)
        layout.addWidget(self.content, 1)
        
        # Connect signals
        self.orch.status_changed.connect(self.on_status)
        self.orch.status_changed.connect(self.avatar.on_status)
        self.orch.transcript_changed.connect(self.transcript.setPlainText)
        self.orch.reply_changed.connect(self.on_reply)
        self.orch.face_changed.connect(self.on_face_present)
        self.orch.frame_ready.connect(self.camera.update_frame)
        self.orch.student_list_changed.connect(self.populate_students)
        
        if self.cam_worker:
            self.cam_worker.frame.connect(self.orch.on_frame)
            self.cam_worker.face_present.connect(self.orch.on_face_present)
            self.cam_worker.face_identified.connect(self.orch.on_face_identified)
        
        self.orch.refresh_students()
    
    def toggle_sidebar(self):
        if self.sidebar.isVisible():
            self.sidebar.hide()
            self.toggle_btn.setText("☰")
        else:
            self.sidebar.show()
            self.toggle_btn.setText("✕")
    
    def on_status(self, mode, status):
        self.status_chip.setText(mode)
    
    def on_face_present(self, present):
        self.face_chip.setText("👤 Present" if present else "👤 No face")
        self.capture_btn.setEnabled(present and self.student_list.selectedItems())
    
    def on_reply(self, text):
        self.response.setPlainText(text)
        cursor = self.response.textCursor()
        cursor.movePosition(QTextCursor.End)
        self.response.setTextCursor(cursor)
    
    def populate_students(self, students):
        self.student_list.clear()
        for sid, name, _ in students:
            item = QListWidgetItem(name)
            item.setData(Qt.UserRole, sid)
            self.student_list.addItem(item)
    
    def on_student_selected(self, item):
        sid = item.data(Qt.UserRole)
        self.orch.select_student(sid)
        self.capture_btn.setEnabled(self.face_chip.text() == "👤 Present")
    
    def add_student(self):
        name = self.student_name.text().strip()
        if name:
            self.orch.add_student(name)
            self.student_name.clear()
    
    def capture_face(self):
        if not self.cam_worker or not self.current_frame:
            return
        
        items = self.student_list.selectedItems()
        if not items:
            return
        
        sid = items[0].data(Qt.UserRole)
        name = items[0].text()
        
        self.capture_status.setText("📸 Capturing...")
        QApplication.processEvents()
        
        try:
            # Save frame to temp file
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as f:
                temp_path = f.name
                self.current_frame.save(temp_path)
            
            # Read with OpenCV
            img = cv2.imread(temp_path)
            rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            
            # Get face encoding
            encodings = face_recognition.face_encodings(rgb)
            if encodings:
                self.db.set_student_face_encoding(sid, encodings[0])
                self.capture_status.setText(f"✅ Face captured for {name}")
                self.cam_worker.reload_faces()
            else:
                self.capture_status.setText("❌ No face detected")
            
            os.unlink(temp_path)
            
        except Exception as e:
            self.capture_status.setText(f"❌ Error: {str(e)[:20]}")
        
        QTimer.singleShot(3000, lambda: self.capture_status.setText(""))
    
    def set_current_frame(self, image):
        self.current_frame = image

# ========== Main ==========
def main():
    # Load config
    config = {}
    if CONFIG_PATH.exists():
        with open(CONFIG_PATH) as f:
            config = json.load(f)
    else:
        config = {
            "vosk_model_path": str(Path.home() / "jarvis_models" / "vosk-model-small-en-us-0.15"),
            "llm_model": "tinyllama",
            "camera_index": 0
        }
        with open(CONFIG_PATH, 'w') as f:
            json.dump(config, f, indent=2)
    
    # Init DB
    db = DB(DB_PATH)
    
    # Create app
    app = QApplication(sys.argv)
    
    # Start camera thread
    cam_thread = QThread()
    cam_worker = CameraWorker(db)
    cam_worker.moveToThread(cam_thread)
    cam_thread.started.connect(cam_worker.start)
    cam_thread.start()
    
    # Start orchestrator
    orch_thread = QThread()
    orch = Orchestrator(config, db)
    orch.moveToThread(orch_thread)
    orch_thread.started.connect(orch.start)
    orch_thread.start()
    
    # Create window
    win = MainWindow(db, orch, cam_worker)
    win.show()
    
    # Connect frame signal
    cam_worker.frame.connect(win.set_current_frame)
    
    # Cleanup
    def shutdown():
        orch.stop()
        cam_worker.stop()
        orch_thread.quit()
        cam_thread.quit()
        orch_thread.wait(2000)
        cam_thread.wait(2000)
        db.close()
    
    app.aboutToQuit.connect(shutdown)
    
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
EOF

# Create default config
print_status "Creating default configuration..."
cat > ~/jarvis_app/data/config.json << EOF
{
    "vosk_model_path": "$HOME/jarvis_models/vosk-model-small-en-us-0.15",
    "llm_model": "$(cat ~/jarvis_default_model.txt 2>/dev/null || echo 'tinyllama')",
    "camera_index": 0,
    "temperature": 0.85,
    "num_predict": 256
}
EOF

# Create run script
print_status "Creating run script..."
cat > ~/jarvis_app/run_jarvis.sh << EOF
#!/bin/bash
source ~/jarvis_env/bin/activate
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
export DISPLAY=:0
cd ~/jarvis_app
python3 jarvis_jetson.py
EOF

chmod +x ~/jarvis_app/run_jarvis.sh

# Create desktop entry
print_status "Creating desktop entry..."
cat > ~/.local/share/applications/jarvis.desktop << EOF
[Desktop Entry]
Name=JARVIS AI Assistant
Comment=Your personal AI assistant
Exec=$HOME/jarvis_app/run_jarvis.sh
Icon=$HOME/jarvis_app/icon.png
Terminal=false
Type=Application
Categories=Utility;
EOF

# Create systemd service (optional)
print_status "Create systemd service? (y/n)"
read -r create_service
if [[ "$create_service" =~ ^[Yy]$ ]]; then
    sudo bash -c "cat > /etc/systemd/system/jarvis.service << EOF
[Unit]
Description=JARVIS AI Assistant
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/jarvis_app
Environment=\"PATH=$HOME/jarvis_env/bin:/usr/local/cuda/bin:/usr/bin:/bin\"
ExecStart=$HOME/jarvis_app/run_jarvis.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"
    
    sudo systemctl daemon-reload
    echo "To enable service: sudo systemctl enable jarvis.service"
    echo "To start service: sudo systemctl start jarvis.service"
fi

# Final instructions
print_success "Installation complete!"
echo ""
echo "========================================="
echo "JARVIS AI Assistant - Installation Complete"
echo "========================================="
echo ""
echo "To run JARVIS:"
echo "  1. Start Ollama: ollama serve &"
echo "  2. Run the app: ~/jarvis_app/run_jarvis.sh"
echo ""
echo "Or if you created the systemd service:"
echo "  sudo systemctl start jarvis.service"
echo ""
echo "Default wake word models path: ~/jarvis_models/"
echo "Configuration file: ~/jarvis_app/data/config.json"
echo ""
echo "To test CUDA: python3 -c \"import torch; print(torch.cuda.is_available())\""
echo ""

# Make the script executable
chmod +x ~/jarvis_app/run_jarvis.sh

print_success "You can now run JARVIS with: ~/jarvis_app/run_jarvis.sh"
