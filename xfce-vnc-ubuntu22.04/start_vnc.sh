#!/bin/bash

# 设置环境变量
export USER=user
export HOME=/home/user

# 启动 VNC 服务器并设置显示参数
vncserver :1 -geometry 1280x720 -depth 24

# 保持容器运行
#tail -f /dev/null

# 8888 是你将暴露给Web浏览器的WebSocket端口，而 localhost:5901 是你的VNC服务器运行的地址和端口
/home/user/noVNC/utils/novnc_proxy --listen 8888 --vnc localhost:5901