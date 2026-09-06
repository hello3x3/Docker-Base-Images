FROM nvidia/cuda:13.3.1-devel-ubuntu24.04

LABEL maintainer="shujiuhe <shujiuhe@outlook.com>"

SHELL [ "/bin/bash", "--login", "-c" ]

# Start as root
USER root

# 更换 USTC 源
# Ubuntu 24.04 的源已迁移到 deb822 格式 /etc/apt/sources.list.d/ubuntu.sources
RUN sed -i -e 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' \
            -e 's@//security.ubuntu.com@//mirrors.ustc.edu.cn@g' \
            /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get clean && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y vim git locales openssh-server tzdata

# 安装并更换中文字体
RUN locale-gen en_US.UTF-8 zh_CN.utf8 && \
    touch /opt/nvidia/entrypoint.sh && \
    echo '#!/bin/bash' >> /opt/nvidia/entrypoint.sh && \
    chmod +x /opt/nvidia/entrypoint.sh && \
    echo 'export LANG=en_US.UTF-8' >> /opt/nvidia/entrypoint.sh && \
    echo 'export LC_CTYPE=zh_CN.UTF-8' >> /opt/nvidia/entrypoint.sh

# 更换系统时间（tzdata 由上方 apt 层安装，无需 COPY 时区文件）
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo "$TZ" > /etc/timezone

# 安装ssh-service
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \
    sed -i '/#PermitRootLogin yes/d' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo root:5233 | chpasswd && \
    echo -e 'if ! service ssh status &> /dev/null; then\n    service ssh start\nfi' >> /opt/nvidia/entrypoint.sh

# 可编程 ssh 启动器（Slurm+pyxis/enroot 场景：读 SSH_PORT 环境变量决定端口并打印实际端口）
# 注意：不要在本镜像设置 ENV SSH_PORT，否则 pyxis 默认传环境变量时镜像值优先，会盖住用户传入值
COPY start_ssh.sh /opt/start_ssh.sh
RUN chmod +x /opt/start_ssh.sh && \
    mkdir -p /run/sshd

# 为 root 公钥登录预留 authorized_keys 挂载点（配合 --container-mounts 把宿主机公钥挂进来）
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# 安装miniconda3
RUN wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    chmod +x Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    bash Miniconda3-py310_22.11.1-1-Linux-x86_64.sh -b -p /usr/local/miniconda3 && \
    rm Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    /usr/local/miniconda3/bin/conda init && \
    /usr/local/miniconda3/bin/conda config --set show_channel_urls yes && \
    /usr/local/miniconda3/bin/conda config --remove channels defaults && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/main && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/r && \
    /usr/local/miniconda3/bin/conda config --add channels https://mirrors.ustc.edu.cn/anaconda/pkgs/msys2 && \
    /usr/local/miniconda3/bin/pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/simple && \
    echo 'export PATH="/usr/local/miniconda3/bin:$PATH"' >> /etc/profile && \
    echo '. /usr/local/miniconda3/etc/profile.d/conda.sh' >> ~/.profile

# 保证cuda不掉（使用 /usr/local/cuda 通用软链，后续升级 13.x 小版本无需改动）
RUN echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' >> /opt/nvidia/entrypoint.sh && \
    echo 'export PATH=$PATH:/usr/local/cuda/bin' >> /opt/nvidia/entrypoint.sh && \
    echo 'export CUDA_HOME=$CUDA_HOME:/usr/local/cuda/' >> /opt/nvidia/entrypoint.sh && \
    echo '. /opt/nvidia/nvidia_entrypoint.sh' >> /opt/nvidia/entrypoint.sh && \
    echo -e '\nset ts=4\nset softtabstop=4\nset shiftwidth=4\nset expandtab\nset autoindent' >> /etc/vim/vimrc

ENTRYPOINT [ "/opt/nvidia/entrypoint.sh" ]

WORKDIR /workspace
