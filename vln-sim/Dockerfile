FROM cuda12.1.0-cudnn8-devel-ubuntu22.04

LABEL maintainer="shujiuhe <shujiuhe@outlook.com>"

SHELL [ "/bin/bash", "--login", "-c" ]

# Set Environment Variables
ENV DEBIAN_FRONTEND noninteractive

# Start as root
USER root

ARG CONDA_ENV="dev"

# ==========================================================================
# 前置操作
# ==========================================================================

RUN apt-get update -y && \
    apt-get upgrade -y && \
    apt-get install build-essential cmake git pkg-config libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev libv4l-dev libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev gfortran openexr libatlas-base-dev python3-dev python3-numpy libtbb2 libtbb-dev -y

RUN conda create -n ${CONDA_ENV} python=3.11 -y && \
    conda activate ${CONDA_ENV} && \
    pip install numpy pandas && \
    # https://pytorch.org/get-started/previous-versions/
    pip install torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2

RUN conda activate ${CONDA_ENV} && \
    pip install opencv-python opencv-contrib-python && \
    pip install msgpack==1.0.4 tornado==4.5.3 numpy lmdb msgpack_numpy dill yacs && \
    pip install wget && \
    # https://github.com/fbcotter/py3nvml
    pip install py3nvml && \
    pip install nvitop

# ==========================================================================
# OpenCV
# ==========================================================================

RUN conda activate ${CONDA_ENV} && \
    cd /usr/local && \
    git clone https://github.com/opencv/opencv.git && \
    git clone https://github.com/opencv/opencv_contrib.git && \
    cd opencv && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=RELEASE -D CMAKE_INSTALL_PREFIX=/usr/local -D INSTALL_C_EXAMPLES=ON -D INSTALL_PYTHON_EXAMPLES=ON -D OPENCV_GENERATE_PKGCONFIG=ON -D OPENCV_EXTRA_MODULES_PATH=/usr/local/opencv_contrib/modules -D BUILD_EXAMPLES=ON .. && \
    make -j16 && \
    make install

# ==========================================================================
# MP3D
# ==========================================================================

COPY --chown=root:root to_opencv4.sh /tmp/to_opencv4.sh

RUN conda activate ${CONDA_ENV} && \
    chmod 777 /tmp/to_opencv4.sh && \
    pip install opencv-python opencv-contrib-python numpy pandas networkx && \
    apt-get install libjsoncpp-dev libepoxy-dev libglm-dev libosmesa6 libosmesa6-dev libglew-dev -y && \
    sed -i 's/# define SIGSTKSZ sysconf (_SC_SIGSTKSZ)/# define SIGSTKSZ 16384/g' /usr/include/x86_64-linux-gnu/bits/sigstksz.h

RUN conda activate ${CONDA_ENV} && \
    mkdir -p /public/github && cd /public/github && \
    # git clone --recursive https://github.com/peteanderson80/Matterport3DSimulator.git && \
    git clone https://github.com/peteanderson80/Matterport3DSimulator.git && \
    bash /tmp/to_opencv4.sh ./Matterport3DSimulator && \
    cd ./Matterport3DSimulator && \
    git clone https://github.com/pybind/pybind11.git && \
    cd pybind11 && git checkout v2.11.1 && \
    cd /public/github/Matterport3DSimulator && mkdir build && cd build && \
    cmake -DPYTHON_EXECUTABLE:FILEPATH=/usr/local/miniconda3/envs/${CONDA_ENV}/bin/python \
    -DPYTHON_LIBRARY=/usr/local/miniconda3/envs/${CONDA_ENV}/lib/libpython"$(python -V 2>&1 | grep -oP '(?<=Python )(\d+\.\d+)')".so \
    -DPYTHON_INCLUDE_DIR=/usr/local/miniconda3/envs/${CONDA_ENV}/include/python"$(python -V 2>&1 | grep -oP '(?<=Python )(\d+\.\d+)')"/ \
    -DEGL_RENDERING=ON .. && \
    make

RUN echo -e $"\
\n\
export PYTHONPATH=$PYTHONPATH:/public/github/Matterport3DSimulator/build \n\
\n\
" >> ~/.bashrc

# ==========================================================================
# Habitat
# ==========================================================================

RUN conda activate ${CONDA_ENV} && \
    pip install cmake==3.25.0 && \
    mkdir -p /public/github && cd /public/github && \
    git clone --recursive https://github.com/facebookresearch/habitat-sim.git && \
    cd habitat-sim && \
    git checkout v0.2.5 && \
    pip install -r requirements.txt && \
    python setup.py install --headless --with-cuda

# ==========================================================================
# dev: custom
# ==========================================================================



# ==========================================================================
# 后处理
# ==========================================================================

USER root

WORKDIR /workspace
