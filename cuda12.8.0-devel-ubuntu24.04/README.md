# cuda12.8.0-devel-ubuntu24.04

CUDA 12.8.0 (devel, 无系统级 cuDNN) + Ubuntu 24.04 开发基座。
与 `cuda13.3.1-devel-ubuntu24.04` 同构（ssh / 免密 / conda / 挂载点配置完全一致），仅 CUDA 大版本不同。

> 为什么是 12.8 而不是 13.3.1：本集群节点驱动 `595.71.05` 最高支持 **CUDA 13.2**，
> 跑 13.3.1 镜像会被 pyxis 以 `cuda>=13.3 unsatisfied` 拒绝挂载驱动；
> CUDA 12.8 只需驱动 >= 570，当前驱动完全满足。

## 构建

```bash
docker build -t cuda12.8.0-devel-ubuntu24.04:latest .
```

## docker 直接使用

```bash
docker run -it --rm \
  -e SSH_PORT=2222 \
  --gpus all \
  cuda12.8.0-devel-ubuntu24.04:latest /opt/start_ssh.sh
```

> 不设 `SSH_PORT` 时（即不传端口参数），root 与非 root 统一默认监听 **52300**。

## Slurm + pyxis/enroot 使用（可编程 sshd 端口）

关键点（均来自 pyxis 官方行为）：

- 环境变量用 `--container-env=SSH_PORT` 传入（提交前先 `export SSH_PORT=2222`）；
  镜像内**不要**设置 `ENV SSH_PORT`，否则镜像值优先、host 传入值会被盖住
- pyxis 默认**不执行**镜像 ENTRYPOINT，直接把 `/opt/start_ssh.sh` 作为命令传入最可靠
- ⚠️ **不要给 sshd 加 `--container-remap-root`**（userns remap 会让 Ubuntu sshd 拒绝服务，
  见下方「公钥登录」警告）；一律用 **`--no-container-remap-root`**
- sshd 端口 <1024 需要 root：以集群 root 提交即是真 root；普通用户直接选 >=1024 的端口（默认 52300）

```bash
# 1) root 模式（以集群 root 提交 = 真 root：密码 root:5233 或公钥）
export SSH_PORT=2222
srun \
  --no-container-remap-root \
  --container-image=<registry#镜像或本地.sqsh> \
  --container-env=SSH_PORT \
  /opt/start_ssh.sh

# 2) 非 root 模式（仅公钥登录；需把公钥放入 ~/.ssh/authorized_keys，home 记得挂载）
export SSH_PORT=3333
srun \
  --no-container-remap-root \
  --container-image=<镜像> \
  --container-env=SSH_PORT \
  --container-mounts=$HOME:$HOME \
  /opt/start_ssh.sh

# 3) 起 sshd 的同时还要交互 shell：把命令追加在脚本后面
srun --pty --no-container-remap-root --container-image=<镜像> \
  --container-env=SSH_PORT \
  /opt/start_ssh.sh bash -l
```

脚本启动后会在 srun 输出里打印**实际监听端口**和连接示例：

```
 [start_ssh] sshd 实际监听端口: 2222 (PID=xxx)
 [start_ssh] 连接示例: ssh -p 2222 root@<节点IP>
```

## 公钥登录：把 authorized_keys 挂进容器

> ⚠️ 重要：本集群 pyxis 默认开启 `container-remap-root`（userns），**remap 出来的 root 会让 Ubuntu sshd 直接拒绝服务**
> （`permanently_set_uid: was able to restore old [e]gid` / `/run/sshd must be owned by root...`，见 NVIDIA/pyxis#85）。
> 跑 sshd 一律要加 **`--no-container-remap-root`**：以 root 提交则是真 root（可用密码 root:5233），
> 以普通用户提交则是非 root（仅公钥）。

镜像预置了两个公钥挂载点：
- `/root/.ssh/authorized_keys`（root 模式用）
- `/opt/ssh-authorized_keys`（非 root 模式用，配合环境变量 `SSH_AUTHORIZED_KEYS`）

```bash
# 1) root 模式（须以集群 root 提交）+ 公钥登录
export SSH_PORT=2222
export SSH_HOSTKEY_DIR=/share/home/shujiuhe/.ssh-hostkeys   # 持久化 host key
srun \
  --no-container-remap-root \
  --container-image=<镜像> \
  --container-env=SSH_PORT,SSH_HOSTKEY_DIR \
  --container-mounts=/share/home/shujiuhe/.ssh/authorized_keys:/root/.ssh/authorized_keys:ro \
  /opt/start_ssh.sh
#    不挂钥匙也行：root 模式直接密码 root:5233 登录
```

```bash
# 2) 非 root 模式：把整个 home 挂进去（sshd 读 passwd home 下 ~/.ssh/authorized_keys）
srun \
  --no-container-remap-root \
  --container-image=<镜像> \
  --container-env=SSH_PORT \
  --container-mounts=/share/home/shujiuhe:/share/home/shujiuhe \
  /opt/start_ssh.sh
#    连接用户名 = 提交用户名（shujiuhe），不是 root
```

```bash
# 3) 非 root + 不挂 home（推荐：容器完全碰不到宿主 ~/.bashrc 等点文件）
#    只把 authorized_keys 单文件挂到镜像挂载点 /opt/ssh-authorized_keys
export SSH_PORT=2222
export SSH_AUTHORIZED_KEYS=/opt/ssh-authorized_keys
srun \
  --no-container-remap-root \
  --container-image=<镜像> \
  --container-env=SSH_PORT,SSH_AUTHORIZED_KEYS \
  --container-mounts=/share/home/shujiuhe/.ssh/authorized_keys:/opt/ssh-authorized_keys:ro \
  /opt/start_ssh.sh
```

> 需要 GPU 时记得给 srun 加 GPU 分配（`--gres=gpu:1`；本集群 slurm cgroup 限制下，
> 不加分配的任务看不到 `/dev/nvidia*`，`nvidia-smi` 报 No devices 属正常）。
> 若报 `nvidia-container-cli: requirement error: unsatisfied condition: cuda>=xx`，
> 是节点驱动支持的 CUDA 上限低于镜像大版本：本集群驱动 595.71.05 = CUDA 13.2，
> 所以这里选 12.8 镜像（需要驱动 >= 570）。

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
