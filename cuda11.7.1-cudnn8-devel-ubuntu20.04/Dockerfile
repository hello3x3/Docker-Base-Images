FROM registry.cn-hangzhou.aliyuncs.com/niuvs/niuvs-team-base-env:11.7.1-cudnn8-devel-ubuntu20.04-v1.0

LABEL maintainer="shujiuhe <shujiuhe@outlook.com>"

SHELL [ "/bin/bash", "--login", "-c" ]

# Set Environment Variables
ENV DEBIAN_FRONTEND noninteractive

# Start as root
USER root

# 更换清华源
RUN echo -e 'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse\n'\
'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse\n'\
'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse\n\n'\
'deb http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse\n'\
'# deb-src http://security.ubuntu.com/ubuntu/ focal-security main restricted universe multiverse\n\n\n'\
'# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-proposed main restricted universe multiverse' > /etc/apt/sources.list && \
    apt-get clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends vim git locales openssh-server wget

# 删除conda环境
RUN rm -rf /public/APP/ && \
    rm -rf ~/.conda && \
    sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' ~/.bashrc && \
    sed -i '/conda activate dev/d' ~/.bashrc && \ 
    sed -i '/export PATH=\/public\/APP\/anaconda3\/bin:\$PATH/d' /etc/profile && \
    sed -i '/. \/public\/APP\/anaconda3\/etc\/profile.d\/conda.sh/d' ~/.profile && \
    source ~/.bashrc

# 重新安装miniconda3
RUN wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    chmod +x Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    bash Miniconda3-py310_22.11.1-1-Linux-x86_64.sh -b -p /usr/local/miniconda3 && \
    rm Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    /usr/local/miniconda3/bin/conda init && \
    /usr/local/miniconda3/bin/conda config --set show_channel_urls yes && \
    /usr/local/miniconda3/bin/conda config --remove channels defaults && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/pro && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/msys2 && \
    /usr/local/miniconda3/bin/pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
    echo "export PATH=\"/usr/local/miniconda3/bin:$PATH\"" >> /etc/profile && \
    echo ". /usr/local/miniconda3/etc/profile.d/conda.sh" >> ~/.profile

# 安装并更换中文字体
RUN locale-gen en_US.UTF-8 zh_CN.utf8 && \
    touch /opt/nvidia/entrypoint.sh && \
    echo '#!/bin/bash' >> /opt/nvidia/entrypoint.sh && \
    chmod +x /opt/nvidia/entrypoint.sh && \
    echo "export LANG=en_US.UTF-8" >> /opt/nvidia/entrypoint.sh && \
    echo "export LC_CTYPE=zh_CN.UTF-8" >> /opt/nvidia/entrypoint.sh

# 安装ssh-service
RUN sed -i "s/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g" /etc/ssh/sshd_config && \
    sed -i "/#PermitRootLogin yes/d" /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo root:5233 | chpasswd && \
    echo -e "if ! service ssh status &> /dev/null; then\n    service ssh start\nfi" >> /opt/nvidia/entrypoint.sh

# 保证cuda不掉
RUN echo -e "\nset ts=4\nset softtabstop=4\nset shiftwidth=4\nset expandtab\nset autoindent" >> /etc/vim/vimrc && \
    echo "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-11.7/lib64/" >> /opt/nvidia/entrypoint.sh && \
    echo "export PATH=$PATH:/usr/local/cuda-11.7/bin/" >> /opt/nvidia/entrypoint.sh && \
    echo "export CUDA_HOME=$CUDA_HOME:/usr/local/cuda-11.7/" >> /opt/nvidia/entrypoint.sh && \
    echo ". /opt/nvidia/nvidia_entrypoint.sh" >> /opt/nvidia/entrypoint.sh

ENTRYPOINT [ "/opt/nvidia/entrypoint.sh" ]

USER root

WORKDIR /workspace
