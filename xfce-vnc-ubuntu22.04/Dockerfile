FROM ubuntu:22.04

LABEL maintainer="shujiuhe <shujiuhe@outlook.com>"

SHELL [ "/bin/bash", "--login", "-c" ]

# Start as root
USER root

# 更换清华源
RUN echo -e 'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse\n'\
'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse\n'\
'deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse\n\n'\
'deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse\n'\
'# deb-src http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse\n\n\n'\
'# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse\n'\
'# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-proposed main restricted universe multiverse' > /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y ca-certificates && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get install --no-install-recommends -y vim git wget curl sudo gnupg locales software-properties-common python3-numpy && \
    apt-get clean

# 更换系统时间
COPY --chown=root:root Shanghai /usr/share/zoneinfo/Asia/Shanghai
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# 安装并更换中文字体
RUN locale-gen en_US.UTF-8 zh_CN.utf8 && \
    echo 'export LANG=en_US.UTF-8' >> /etc/bash.bashrc && \
    echo 'export LC_CTYPE=zh_CN.UTF-8' >> /etc/bash.bashrc && \
    echo -e '\nset ts=4\nset softtabstop=4\nset shiftwidth=4\nset expandtab\nset autoindent' >> /etc/vim/vimrc

# 添加 NodeSource 的签名密钥和 PPA 并安装 Node.js LTS 版本
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y nodejs

# 安装 Xfce 桌面环境和 VNC 服务器
RUN apt-get install --no-install-recommends -y xfce4 xfce4-goodies \
    tightvncserver \
    dbus-x11 \
    x11-xserver-utils \
    xfonts-base && \
    apt-get install --reinstall -y adwaita-icon-theme-full

# 创建新用户并配置密码
RUN adduser --force-badname --disabled-password --gecos '' --shell /bin/bash user && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'root:5233' | chpasswd && \
    echo 'user:5233' | chpasswd && \
    adduser user sudo && \
    adduser user audio && \
    adduser user video

# clone noVNC
USER user
ENV USER user
COPY --chown=user:user start_vnc.sh /usr/local/bin/start_vnc.sh
RUN cd /home/user && \
    git clone https://github.com/novnc/noVNC.git && \
    chmod +x /usr/local/bin/start_vnc.sh

# 设置 VNC 服务器配置
RUN cd /home/user && \
    mkdir -p /home/user/.vnc && \
    echo "5233" | vncpasswd -f > /home/user/.vnc/passwd && \
    chmod 600 /home/user/.vnc/passwd && \
    echo "startxfce4 &" > /home/user/.vnc/xstartup && \
    chmod +x /home/user/.vnc/xstartup

# 启动 VNC 服务器和 Xfce
CMD ["/usr/local/bin/start_vnc.sh"]

WORKDIR /home/user
