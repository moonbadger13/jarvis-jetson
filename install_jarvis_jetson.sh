#!/bin/bash

# JARVIS AI Assistant - Jetson Orin (Auto-detecting PyTorch)
# Run with: bash install_jarvis_jetson.sh

set -e

echo "========================================="
echo "JARVIS AI Assistant - Jetson Orin"
echo "========================================="

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ---------- System check ----------
if [ ! -f /etc/nv_tegra_release ]; then
    print_warning "Not a Jetson device. Continue anyway? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then exit 1; fi
fi

# ---------- Update & dependencies ----------
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

print_status "Installing basic dependencies..."
sudo apt install -y \
    python3-pip python3-dev python3-venv build-essential cmake git wget curl \
    portaudio19-dev libsndfile1 ffmpeg libopenblas-dev liblapack-dev \
    libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev \
    libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libatlas-base-dev \
    libhdf5-dev libhdf5-serial-dev libhdf5-103 \
    libqt5gui5 libqt5core5a libqt5widgets5 libssl-dev \
    python3-pyqt5 python3-pyqt5.qtsvg python3-sip-dev \
    qtbase5-dev qtchooser qt5-qmake qtbase5-dev-tools \
    libxcb-xinerama0 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-randr0 libxcb-render-util0 libxcb-shape0 libxcb-sync1 \
    libxcb-xfixes0 libxcb-xkb1 libxkbcommon-x11-0 \
    libgl1-mesa-glx libgl1-mesa-dri mesa-utils

# qt5-default is optional (not in newer Ubuntu)
if apt-cache show qt5-default &>/dev/null; then
    sudo apt install -y qt5-default
fi
print_success "Dependencies installed"

# ---------- CUDA environment ----------
print_status "Setting up CUDA environment..."
if ! grep -q "CUDA_HOME" ~/.bashrc; then
    echo 'export CUDA_HOME=/usr/local/cuda' >> ~/.bashrc
    echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ~/.bashrc
    echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ~/.bashrc
    echo 'export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1' >> ~/.bashrc
fi
source ~/.bashrc
print_success "CUDA configured"

# ---------- Virtual environment ----------
print_status "Creating Python virtual environment..."
cd ~
python3 -m venv jarvis_env --system-site-packages
source ~/jarvis_env/bin/activate
pip install --upgrade pip setuptools wheel
print_success "Virtual environment ready"

# ---------- Detect JetPack & Python ----------
print_status "Detecting JetPack version..."
JETPACK_VERSION=$(grep -oP 'R\d+' /etc/nv_tegra_release | head -1 | tr -d 'R')
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
print_status "JetPack major: ${JETPACK_VERSION:-unknown}, Python: $PYTHON_VERSION"

# ---------- Select correct PyTorch wheel ----------
TORCH_WHEEL=""
case $JETPACK_VERSION in
    32|34)  # JetPack 4.x (L4T R32/R34)
        if [ "$PYTHON_VERSION" == "3.6" ]; then
            TORCH_WHEEL="https://developer.download.nvidia.com/compute/redist/jp/v46/pytorch/torch-1.10.0-cp36-cp36m-linux_aarch64.whl"
        else
            print_error "JetPack 4 requires Python 3.6, you have $PYTHON_VERSION"
            exit 1
        fi
        ;;
    35)  # JetPack 5.x (L4T R35)
        if [ "$PYTHON_VERSION" == "3.8" ]; then
            TORCH_WHEEL="https://developer.download.nvidia.com/compute/redist/jp/v512/pytorch/torch-2.1.0a0+41361538.nv23.06-cp38-cp38-linux_aarch64.whl"
        else
            print_error "JetPack 5 requires Python 3.8, you have $PYTHON_VERSION"
            exit 1
        fi
        ;;
    36)  # JetPack 6.x (L4T R36)
        if [ "$PYTHON_VERSION" == "3.10" ]; then
            TORCH_WHEEL="https://developer.download.nvidia.com/compute/redist/jp/v60/pytorch/torch-2.1.0-cp310-cp310-linux_aarch64.whl"
        else
            print_error "JetPack 6 requires Python 3.10, you have $PYTHON_VERSION"
            exit 1
        fi
        ;;
    *)
        print_warning "Unknown JetPack version. Please manually install PyTorch from:"
        print_warning "https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048"
        print_warning "Then run: pip install <your-wheel>.whl"
        ;;
esac

# ---------- Install PyTorch ----------
if [ -n "$TORCH_WHEEL" ]; then
    print_status "Downloading PyTorch wheel: $TORCH_WHEEL"
    wget -O torch.whl "$TORCH_WHEEL" || {
        print_error "Download failed. Check URL or network."
        exit 1
    }
    pip install --no-cache-dir torch.whl
    rm torch.whl
    print_success "PyTorch installed"
else
    print_error "No matching PyTorch wheel. Follow manual instructions above."
    exit 1
fi

# ---------- torchvision ----------
print_status "Installing torchvision from source..."
sudo apt install -y libjpeg-dev zlib1g-dev libpython3-dev libavcodec-dev libavformat-dev libswscale-dev
git clone --branch v0.16.0 https://github.com/pytorch/vision torchvision
cd torchvision
export BUILD_VERSION=0.16.0
python3 setup.py install
cd ~
print_success "torchvision installed"

# ---------- dlib (CUDA) ----------
print_status "Installing dlib with CUDA..."
git clone https://github.com/davisking/dlib.git
cd dlib
mkdir build && cd build
cmake .. -DDLIB_USE_CUDA=1 -DUSE_AVX_INSTRUCTIONS=1
cmake --build . --config Release
cd ..
python3 setup.py install --set DLIB_USE_CUDA=1
cd ~
print_success "dlib installed"

# ---------- Other Python packages ----------
pip install face_recognition
pip install numpy scipy sounddevice pypdf webrtcvad openwakeword

# Qt5 only (PySide6 + PyQt5 conflict causes "qt5 default" errors)
# Using PyQt5 for Jetson stability
pip install PyQt5
# ---------- Vosk (ARM64) ----------
pip install https://github.com/alphacep/vosk-api/releases/download/v0.3.45/vosk-0.3.45-py3-none-linux_aarch64.whl

# ---------- FAISS with GPU ----------
print_status "Installing FAISS (GPU)..."
git clone https://github.com/facebookresearch/faiss.git
cd faiss
mkdir build && cd build
cmake -DFAISS_ENABLE_GPU=ON -DCUDAToolkit_ROOT=/usr/local/cuda -DFAISS_ENABLE_PYTHON=ON ..
make -j4
make install
cd ../python
python3 setup.py install
cd ~
print_success "FAISS installed"

# ---------- Ollama ----------
print_status "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh
sleep 3

# ---------- Model selection ----------
print_warning "Choose a model based on your Jetson's RAM:"
echo "1) tinyllama (smallest, fastest)"
echo "2) phi:2.7b (good balance)"
echo "3) mistral:7b (largest, slow)"
echo "4) Skip"
read -p "Enter choice [1-4]: " model_choice
case $model_choice in
    1) ollama pull tinyllama; echo "tinyllama" > ~/jarvis_default_model.txt ;; 
    2) ollama pull phi:2.7b; echo "phi:2.7b" > ~/jarvis_default_model.txt ;; 
    3) ollama pull mistral:7b; echo "mistral:7b" > ~/jarvis_default_model.txt ;; 
    *) echo "Skipping"; echo "tinyllama" > ~/jarvis_default_model.txt ;; 
esac

# ---------- Vosk model ----------
print_status "Downloading Vosk model..."
mkdir -p ~/jarvis_models
cd ~/jarvis_models
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip -o vosk-model-small-en-us-0.15.zip
cd ~
print_success "Vosk model ready"

# ---------- Create app directory and Python script ----------
mkdir -p ~/jarvis_app
mkdir -p ~/jarvis_app/data
cd ~/jarvis_app

# Create the JARVIS Python script
cat > jarvis_jetson.py << 'EOF'
#!/usr/bin/env python3
"""
JARVIS AI Assistant - Jetson Orin
A voice-controlled AI assistant with face recognition and local LLM support
"""

import os
import json
import sys

# Add any necessary imports here
try:
    import numpy as np
    import torch
    import face_recognition
    import ollama
except ImportError as e:
    print(f"Error: Missing dependency - {e}")
    sys.exit(1)

class JarvisAssistant:
    def __init__(self, config_path="data/config.json"):
        """Initialize the JARVIS assistant with configuration"""
        self.config = self.load_config(config_path)
        self.running = False
        
    def load_config(self, config_path):
        """Load configuration from JSON file"""
        try:
            with open(config_path, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Config file not found: {config_path}")
            return {}
    
    def start(self):
        """Start the JARVIS assistant"""
        print("JARVIS AI Assistant starting...")
        self.running = True
        # TODO: Implement main loop
        
    def stop(self):
        """Stop the JARVIS assistant"""
        print("JARVIS AI Assistant stopping...")
        self.running = False

if __name__ == "__main__":
    jarvis = JarvisAssistant()
    try:
        jarvis.start()
    except KeyboardInterrupt:
        jarvis.stop()
        print("\nShutdown gracefully.")
EOF

# Config
cat > ~/jarvis_app/data/config.json << EOF
{
    "vosk_model_path": "$HOME/jarvis_models/vosk-model-small-en-us-0.15",
    "llm_model": "$(cat ~/jarvis_default_model.txt 2>/dev/null || echo 'tinyllama')",
    "camera_index": 0,
    "temperature": 0.85,
    "num_predict": 256
}
EOF

# Run script
cat > ~/jarvis_app/run_jarvis.sh << EOF
#!/bin/bash
source ~/jarvis_env/bin/activate
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH
export DISPLAY=:0
# Fix Qt platform plugin issues on Jetson
export QT_QPA_PLATFORM=xcb
cd ~/jarvis_app
python3 jarvis_jetson.py
EOF
chmod +x ~/jarvis_app/run_jarvis.sh

# Desktop entry (optional)
mkdir -p ~/.local/share/applications
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

print_success "Installation complete!"
echo ""
echo "To run JARVIS:"
echo "  1. Start Ollama: ollama serve &"
echo "  2. ~/jarvis_app/run_jarvis.sh"
