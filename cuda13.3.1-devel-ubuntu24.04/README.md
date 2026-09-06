# cuda13.3.1-devel-ubuntu24.04

CUDA 13.3.1 (devel, 无系统级 cuDNN) + Ubuntu 24.04 开发基座。
换 USTC 源（deb822）、tzdata 时区(Asia/Shanghai)、ssh、miniconda3、中文字体。
与旧版 `12.1.0-cudnn8-devel-ubuntu22.04` 结构一致，压缩体积约 3.84 GiB。

## 构建

```bash
docker build -t cuda13.3.1-devel-ubuntu24.04:latest .
```

## docker 直接使用

```bash
docker run -it --rm \
  -e SSH_PORT=2222 \
  --gpus all \
  cuda13.3.1-devel-ubuntu24.04:latest /opt/start_ssh.sh
```

## Slurm + pyxis/enroot 使用（可编程 sshd 端口）

关键点（均来自 pyxis 官方行为）：

- 环境变量用 `--container-env=SSH_PORT` 传入（提交前先 `export SSH_PORT=2222`）；
  镜像内**不要**设置 `ENV SSH_PORT`，否则镜像值优先、host 传入值会被盖住
- pyxis 默认**不执行**镜像 ENTRYPOINT，直接把 `/opt/start_ssh.sh` 作为命令传入最可靠
- sshd 端口 <1024 需要 root：非 root 用户要加 `--container-remap-root`

```bash
# 1) root 模式（ssh 用 root + 密码 5233，或公钥）
export SSH_PORT=2222
srun \
  --container-image=<registry#镜像或本地.sqsh> \
  --container-remap-root \
  --container-env=SSH_PORT \
  /opt/start_ssh.sh

# 2) 非 root 模式（仅公钥登录；需把公钥放入 ~/.ssh/authorized_keys，home 记得挂载）
export SSH_PORT=3333
srun \
  --container-image=<镜像> \
  --container-env=SSH_PORT \
  --container-mounts=$HOME:$HOME \
  /opt/start_ssh.sh

# 3) 起 sshd 的同时还要交互 shell：把命令追加在脚本后面
srun --pty --container-image=<镜像> --container-remap-root \
  --container-env=SSH_PORT \
  /opt/start_ssh.sh bash -l
```

脚本启动后会在 srun 输出里打印**实际监听端口**和连接示例：

```
 [start_ssh] sshd 实际监听端口: 2222 (PID=xxx)
 [start_ssh] 连接示例: ssh -p 2222 root@<节点IP>
```

## 公钥登录：把 authorized_keys 挂进容器

镜像已为 root 预留挂载点 `/root/.ssh/authorized_keys`（空文件，mode 600）。
容器启动时用 `--container-mounts` 把宿主机的公钥文件挂进去即可：

```bash
# root 模式 + 公钥登录（推荐）
export SSH_PORT=2222
export SSH_HOSTKEY_DIR=/share/home/shujiuhe/.ssh-hostkeys   # 持久化 host key（方案1）
srun \
  --container-image=<镜像> \
  --container-remap-root \
  --container-env=SSH_PORT,SSH_HOSTKEY_DIR \
  --container-mounts=/share/home/shujiuhe/.ssh/authorized_keys:/root/.ssh/authorized_keys:ro \
  /opt/start_ssh.sh
```

> 说明：`--container-remap-root` 的 userns 把容器 uid0 映射回宿主提交用户，
> 所以宿主上属主为 `shujiuhe` 的 authorized_keys 在容器内对 root 是"本人文件"，权限检查可通过。

```bash
# 非 root 模式：把用户 home 挂到同路径即可，authorized_keys 原本就在那
srun \
  --container-image=<镜像> \
  --container-env=SSH_PORT \
  --container-mounts=/share/home/shujiuhe:/share/home/shujiuhe \
  /opt/start_ssh.sh   # sshd 以容器内映射用户身份读 ~/.ssh/authorized_keys
```

不想挂载也行：root 模式可直接用镜像内置密码 `root:5233` 登录。

## host key 与 .ssh-hostkeys 说明

- `$HOME/.ssh-hostkeys`（可用 `SSH_HOSTKEY_DIR` 覆盖）是 `start_ssh.sh` 自建的 **sshd host key 目录**，
  不是 OpenSSH 标准路径，也不是 authorized_keys：
  - root 模式默认**不生成**它——直接用镜像内置 `/etc/ssh/ssh_host_*`（同镜像指纹恒定）
  - 只有「非 root」或「显式设置了 SSH_HOSTKEY_DIR」时才生成/复用该目录
- 只有容器**实际运行过** start_ssh.sh、且写入的是**挂载盘**，才能在宿主机对应路径看到它
  （如 `/share/home/shujiuhe/.ssh-hostkeys/`，含 `ssh_host_ed25519_key[.pub]`、`ssh_host_rsa_key[.pub]`），
  隐藏目录需 `ls -a` 查看；若 `$HOME` 在容器内是 `/root`（未挂载），会写进临时 overlay，任务结束即消失

## 注意

- 非 root 模式无法读 /etc/shadow，密码登录不可用，脚本自动切到仅公钥认证
- `chmod 1777 /run/sshd` 会让 **root 模式 sshd 直接拒绝启动**（OpenSSH 校验），
  镜像里只 `mkdir -p /run/sshd`（root 0755）；非 root 模式不依赖该目录写权限
