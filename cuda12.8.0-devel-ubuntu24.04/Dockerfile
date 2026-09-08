# cuda12.8.0-devel-ubuntu24.04 - 与 cuda13.3.1 版本同构，仅基础镜像 CUDA 大版本不同。
# 选 12.8 的原因：本集群节点驱动 595.71.05 最高支持 CUDA 13.2，13.3.1 镜像会被
# pyxis 的 nvidia-container-cli 以 "cuda>=13.3 unsatisfied" 拒绝挂载驱动；
# CUDA 12.8 只需驱动 >= 570（实际 595.71 满足，且完全兼容 12.8 运行时）。
FROM nvidia/cuda:12.8.0-devel-ubuntu24.04

LABEL maintainer="shujiuhe <shujiuhe@outlook.com>"

SHELL [ "/bin/bash", "--login", "-c" ]

# Start as root
USER root

# 更换 USTC 源（Ubuntu 24.04 为 deb822 格式）
RUN sed -i -e 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' \
            -e 's@//security.ubuntu.com@//mirrors.ustc.edu.cn@g' \
            /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get clean && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y vim git locales openssh-server tzdata

# 中文字体 locale，并初始化 entrypoint 脚本
RUN locale-gen en_US.UTF-8 zh_CN.utf8 && \
    touch /opt/nvidia/entrypoint.sh && \
    echo '#!/bin/bash' >> /opt/nvidia/entrypoint.sh && \
    chmod +x /opt/nvidia/entrypoint.sh

# 系统时间
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo "$TZ" > /etc/timezone

# ssh：允许 root 密码登录（root:5233），entrypoint 启动时自动拉起
RUN sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords yes/g' /etc/ssh/sshd_config && \
    sed -i '/#PermitRootLogin yes/d' /etc/ssh/sshd_config && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo root:5233 | chpasswd && \
    echo -e 'if ! service ssh status &> /dev/null; then\n    service ssh start\nfi' >> /opt/nvidia/entrypoint.sh

# 可编程 ssh 启动器（Slurm+pyxis/enroot：读 SSH_PORT 决定端口）
# 注意：镜像内不要设置 ENV SSH_PORT，否则会盖住用户传入值
COPY start_ssh.sh /opt/start_ssh.sh
RUN chmod +x /opt/start_ssh.sh && \
    mkdir -p /run/sshd

# root 公钥登录挂载点
RUN mkdir -p /root/.ssh && \
    touch /root/.ssh/authorized_keys && \
    chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# 非 root 公钥登录挂载点：配合 start_ssh.sh 的 SSH_AUTHORIZED_KEYS=<绝对路径> 使用，
# 只挂 authorized_keys 单文件即可免密登录，无需把整个 $HOME 挂进容器
RUN touch /opt/ssh-authorized_keys && \
    chmod 644 /opt/ssh-authorized_keys

# miniconda3 到 /opt/miniconda3；整体 a+rwX 让所有用户都能改 base；envs 1777 防互删
RUN wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    chmod +x Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    bash Miniconda3-py310_22.11.1-1-Linux-x86_64.sh -b -p /opt/miniconda3 && \
    rm Miniconda3-py310_22.11.1-1-Linux-x86_64.sh && \
    /opt/miniconda3/bin/conda init && \
    chmod -R a+rwX /opt/miniconda3 && \
    chmod 1777 /opt/miniconda3/envs

# conda 全局可用：source 进 login(/etc/profile) 与交互非登录(/etc/bash.bashrc) shell
RUN echo '. /opt/miniconda3/etc/profile.d/conda.sh' >> /etc/profile && \
    echo '. /opt/miniconda3/etc/profile.d/conda.sh' >> /etc/bash.bashrc

# 清掉构建期 conda 缓存（须在下方 ENV 之前，否则会漏清 /opt/miniconda3/pkgs）
RUN /opt/miniconda3/bin/conda clean -afy

# 运行时环境走镜像 ENV：pyxis/enroot 不执行 entrypoint、只注入镜像 ENV，故全终端生效。
# pip/uv 走 USTC 且禁缓存；conda 无禁缓存开关，包缓存指到 /tmp 不残留
ENV PATH="/opt/miniconda3/bin:${PATH}" \
    CUDA_HOME=/usr/local/cuda \
    LANG=en_US.UTF-8 \
    LC_CTYPE=zh_CN.UTF-8 \
    PIP_INDEX_URL=https://mirrors.ustc.edu.cn/pypi/simple \
    PIP_NO_CACHE_DIR=1 \
    UV_DEFAULT_INDEX=https://mirrors.ustc.edu.cn/pypi/simple \
    UV_NO_CACHE=1 \
    CONDA_PKGS_DIRS=/tmp/conda-pkgs

# conda 包缓存目录预置 1777（防 root 先建导致其他用户不可写）
RUN mkdir -p /tmp/conda-pkgs && \
    chmod 1777 /tmp/conda-pkgs

# CUDA 的 PATH/LD_LIBRARY_PATH 由基础镜像 ENV 内置；entrypoint 只补 NVIDIA runtime 脚本与 vim 配置
RUN echo '. /opt/nvidia/nvidia_entrypoint.sh' >> /opt/nvidia/entrypoint.sh && \
    echo -e '\nset ts=4\nset softtabstop=4\nset shiftwidth=4\nset expandtab\nset autoindent' >> /etc/vim/vimrc

ENTRYPOINT [ "/opt/nvidia/entrypoint.sh" ]

WORKDIR /workspace
