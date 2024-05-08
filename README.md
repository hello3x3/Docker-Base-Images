# Docker Base Images

## Quick Start

0. build

    > 需要先cd到目标镜像含有Dockerfile的目录下

    ```bash
    docker build -t 【目标镜像名称】:latest .
    ```

1. run

    > 容器默认开启ssh，通过docker端口映射的方式可直接ssh连接至容器，初始密码5233

    ```bash
    docker run -it \
    -v 【宿主机目录】:【容器内目录】 \
    -p 【宿主机端口】:22 \
    --gpus all \
    --name 【容器名称】 \
    【镜像名称】:latest /bin/bash
    ```

2. start

    > 启动或重启容器

    ```bash
    docker start 【容器名称】
    docker restart 【容器名称】
    ```

3. execute

    > 再次进入一个已启动的容器

    ```bash
    docker exec -it 【容器名称】 /bin/bash

4. stop

    > 关闭一个已启动的容器

    ```bash
    docker stop 【容器名称】
    docker kill 【容器名称】
    ```

5. remove

    > 删除一个已停止的容器

    ```bash
    docker rm 【容器名称】
    ```
