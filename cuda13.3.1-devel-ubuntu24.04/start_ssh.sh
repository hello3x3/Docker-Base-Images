#!/bin/bash
# start_ssh.sh - 以环境变量 SSH_PORT 指定的端口启动 sshd，并打印实际监听端口
#
# 用法（Slurm + pyxis/enroot，推荐显式把脚本作为命令传入，不依赖 ENTRYPOINT）:
#   export SSH_PORT=2222
#   srun --container-image=<镜像> --container-remap-root \
#        --container-env=SSH_PORT /opt/start_ssh.sh
#   想在 sshd 之外再执行别的命令(如交互 shell)时，把命令追加为参数:
#   srun --pty --container-image=<镜像> --container-remap-root \
#        --container-env=SSH_PORT /opt/start_ssh.sh bash -l
#
# 用法（docker）:
#   docker run -d -e SSH_PORT=2222 <镜像> /opt/start_ssh.sh
#
# 说明:
#   - root 模式(默认端口 22)：沿用镜像内置配置(密码 root:5233、PermitRootLogin yes)
#   - 非 root 模式(默认端口 2222)：无法读 /etc/shadow，仅支持公钥登录，
#     公钥放 ~/.ssh/authorized_keys（建议挂载 home）
#   - host key 稳定性: 显式设置 SSH_HOSTKEY_DIR=<挂载盘绝对路径> 可让指纹跨任务稳定
#     (root/非 root 均生效)；否则 root 用镜像内置密钥，非 root 用 $HOME/.ssh-hostkeys
#   - 特权端口(<1024)需要 root，非 root 请用 --container-remap-root 或 SSH_PORT>=1024

set -u

# ---------- 端口解析 ----------
SSH_PORT="${SSH_PORT:-}"
if [ -z "$SSH_PORT" ]; then
    if [ "$(id -u)" -eq 0 ]; then
        SSH_PORT=22
    else
        SSH_PORT=2222
    fi
    echo "[start_ssh] 未设置 SSH_PORT，使用默认端口 $SSH_PORT"
fi
case "$SSH_PORT" in
    (*[!0-9]*|'')
        echo "[start_ssh] 错误: SSH_PORT='$SSH_PORT' 不是合法端口号" >&2
        exit 2 ;;
esac
if [ "$SSH_PORT" -lt 1 ] || [ "$SSH_PORT" -gt 65535 ]; then
    echo "[start_ssh] 错误: SSH_PORT=$SSH_PORT 超出范围 (1-65535)" >&2
    exit 2
fi
if [ "$(id -u)" -ne 0 ] && [ "$SSH_PORT" -lt 1024 ]; then
    echo "[start_ssh] 错误: 非 root 用户无法绑定特权端口 $SSH_PORT。" >&2
    echo "[start_ssh] 请使用 srun --container-remap-root，或设置 SSH_PORT>=1024" >&2
    exit 1
fi

SSHD=/usr/sbin/sshd
PIDFILE=/tmp/sshd.pid
OPTS=(-e -o PidFile="$PIDFILE" -p "$SSH_PORT")

# root 模式下 sshd 要求 /run/sshd 存在且归 root 所有(0755，不能 world-writable)
if [ "$(id -u)" -eq 0 ]; then
    mkdir -p /run/sshd
fi

# ---------- host keys ----------
# host key 策略：
#   未设置 SSH_HOSTKEY_DIR：
#     root    -> 用镜像内置密钥 /etc/ssh/ssh_host_*（同一镜像指纹恒定，容器间共享）
#     非 root -> 生成到 $HOME/.ssh-hostkeys（home 挂载则跨任务复用，否则每次重建）
#   显式设置 SSH_HOSTKEY_DIR=<挂载盘绝对路径>（方案1，root/非 root 均生效）：
#     一律生成/复用该目录密钥 -> 指纹跨任务稳定且按用户/项目隔离
USE_PERSISTENT=0
if [ -n "${SSH_HOSTKEY_DIR:-}" ]; then
    USE_PERSISTENT=1
else
    for f in /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_ed25519_key; do
        [ -r "$f" ] || { USE_PERSISTENT=1; break; }
    done
fi
if [ "$USE_PERSISTENT" -eq 1 ]; then
    KEYDIR="${SSH_HOSTKEY_DIR:-$HOME/.ssh-hostkeys}"
    mkdir -p "$KEYDIR" 2>/dev/null || KEYDIR=/tmp/ssh-hostkeys
    mkdir -p "$KEYDIR"
    chmod 700 "$KEYDIR"
    [ -f "$KEYDIR/ssh_host_ed25519_key" ] || \
        ssh-keygen -q -t ed25519 -N '' -f "$KEYDIR/ssh_host_ed25519_key"
    [ -f "$KEYDIR/ssh_host_rsa_key" ] || \
        ssh-keygen -q -t rsa -b 4096 -N '' -f "$KEYDIR/ssh_host_rsa_key"
    chmod 600 "$KEYDIR"/ssh_host_*_key
    OPTS+=(-o HostKey="$KEYDIR/ssh_host_ed25519_key" -o HostKey="$KEYDIR/ssh_host_rsa_key")
    if [ -n "${SSH_HOSTKEY_DIR:-}" ]; then
        echo "[start_ssh] 使用持久化 host key: $KEYDIR/ (跨任务指纹稳定)"
    else
        echo "[start_ssh] 已生成 host key: $KEYDIR/ (此目录持久化则指纹稳定)"
    fi
fi

# ---------- 非 root 认证策略 ----------
if [ "$(id -u)" -ne 0 ]; then
    OPTS+=(-o UsePAM=no -o PasswordAuthentication=no \
           -o KbdInteractiveAuthentication=no -o PubkeyAuthentication=yes)
    echo "[start_ssh] 非 root 模式: 仅公钥认证 (将你的公钥放入 ~/.ssh/authorized_keys)"
fi

# ---------- 启动 sshd ----------
"$SSHD" "${OPTS[@]}"
RC=$?
if [ "$RC" -ne 0 ]; then
    echo "[start_ssh] sshd 启动失败 (exit=$RC)，请检查上方日志" >&2
    exit 1
fi

# 等待 pidfile 出现
PID=""
for _ in $(seq 1 100); do
    if [ -s "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE")
        kill -0 "$PID" 2>/dev/null && break
    fi
    sleep 0.1
done

# 从 /proc/net/tcp 确认实际监听端口
HEX=$(printf '%04X' "$SSH_PORT")
LISTENING=0
for _ in $(seq 1 100); do
    if awk -v p=":$HEX" '$4=="0A" && index($2,p){f=1} END{exit !f}' \
            /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
        LISTENING=1
        break
    fi
    kill -0 "$PID" 2>/dev/null || break
    sleep 0.1
done

if [ "$LISTENING" -eq 1 ]; then
    IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    NODE="${SLURMD_NODENAME:-$(hostname 2>/dev/null)}"
    echo "============================================================"
    echo " [start_ssh] sshd 实际监听端口: $SSH_PORT (PID=$PID)"
    echo " [start_ssh] 连接示例(节点名): ssh -p $SSH_PORT $(id -un)@${NODE:-<节点名>}"
    echo " [start_ssh] 连接示例(节点IP): ssh -p $SSH_PORT $(id -un)@${IP:-<节点IP>}"
    echo "============================================================"
else
    echo "[start_ssh] 警告: 未能确认端口 $SSH_PORT 正在监听，sshd 可能启动失败" >&2
fi

# ---------- 保持任务存活 / 转交额外命令 ----------
if [ "$#" -gt 0 ]; then
    exec "$@"
fi
trap 'kill "$PID" 2>/dev/null' TERM INT EXIT
while kill -0 "$PID" 2>/dev/null; do
    sleep 5
done
exit 0
