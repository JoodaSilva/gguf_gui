#!/usr/bin/env bash
set -euo pipefail

sudo apt update
sudo apt install gcc-11 g++-11 build-essential -y


# Repository name
REPO_NAME="llama.cpp"
DOCKER_BUILD=${DOCKER_BUILD:-false} # set to true if running during a docker build

# Function to check if a directory is a git repository
is_git_repo() {
  git -C "$1" rev-parse --is-inside-work-tree >/dev/null 2>&1
}

# Check if the repository directory exists and is a git repository
if [ -d "$REPO_NAME" ] && is_git_repo "$REPO_NAME"; then
  echo "The $REPO_NAME repository already exists in the current directory."
else
  echo "No $REPO_NAME repository found in the current directory. Cloning repository..."
  git clone https://github.com/ggerganov/llama.cpp.git --depth=1
fi

pip install --upgrade huggingface_hub pip streamlit watchdog
pip install -r "llama.cpp/requirements/requirements-convert_hf_to_gguf.txt"

# There are other arguments you can add to llama-cpp-python as shown here:
# https://github.com/abetlen/llama-cpp-python
CXX=g++-11  CC=gcc-11 pip install llama-cpp-python
cd llama.cpp

# if CUDA is available, set the llama.cpp build options
if command -v nvcc &>/dev/null; then
  export LLAMA_CUDA=1
fi

# you can add in your build options here
make -j "$(nproc)"
cd ..

if [ "$DOCKER_BUILD" != true ]; then
  echo "Starting Streamlit..."
  # Check if running in Google Colab
  if [ -d "/content" ] || [ -n "${COLAB_RELEASE_TAG+x}" ]; then
    echo "Running in Google Colab. Fetching public IP..."
    PUBLIC_IP=$(wget -q -O - ipv4.icanhazip.com)
    echo "Public IP: $PUBLIC_IP"
    
    # Start Streamlit and localtunnel
    streamlit run main.py & npx localtunnel --port 8501
  else
    # Not running in Colab, start Streamlit normally
    streamlit run main.py --browser.serverAddress 0.0.0.0
  fi
fi
