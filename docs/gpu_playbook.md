# GPU Playbook

这份文档记录 SOAR 比赛中一次 GPU 验证的标准流程。目标是：GPU 实例一到手，就按固定步骤完成环境准备、服务启动、正确性评测、速度评测、日志收集和结果同步。

宿主机脚本在 GPU 实例的宿主机上执行。容器内脚本在进入 SOAR Docker 容器后执行。

## 0. 前置假设

- GPU 实例已经安装 Docker 和 NVIDIA Container Toolkit。
- GPU 宿主机上的工作目录是 `~/soar-workspace`。
- 工作目录包含三个仓库：
  - `sgl-soar`
  - `SOAR-Toolkit`
  - `soar-playbook`
- 模型在容器内的路径是 `/models/MiniCPM-SALA`。

如果路径不一致，先通过环境变量覆盖，再执行脚本。

## 1. 宿主机准备

在 GPU 宿主机上执行：

```bash
cd ~/soar-workspace/soar-playbook

export RUN_ID=$(date +%Y%m%d-%H%M%S)

bash scripts/prepare_host.sh
bash scripts/start_container.sh
```

进入容器：

```bash
docker exec -it "soar-$RUN_ID" bash
```

宿主机上的结果目录是：

```bash
~/soar-workspace/soar-playbook/runs/$RUN_ID
```

## 2. 容器内流程

进入容器后执行：

```bash
cd /workspace/soar-playbook

bash scripts/init_container.sh
bash scripts/start_server.sh
bash scripts/run_correctness.sh
bash scripts/run_speed.sh
bash scripts/collect_results.sh
```

容器内的结果目录是：

```bash
/workspace/soar-playbook/runs/$RUN_ID
```

因为 `soar-playbook` 是从宿主机挂载进容器的，所以宿主机和容器看到的是同一份 run 结果。

## 3. 脚本说明

`scripts/prepare_host.sh`

在宿主机上执行。它会拉取 SOAR 官方基础镜像，clone 或更新 `sgl-soar` 和 `SOAR-Toolkit`，创建 `runs/$RUN_ID`，并写入本次运行的元信息。

`scripts/start_container.sh`

在宿主机上执行。它会启动 SOAR Docker 容器，打开 GPU 访问权限，并把 `sgl-soar`、`SOAR-Toolkit`、`soar-playbook` 三个目录挂载到容器里。它也会把 `RUN_ID`、`MODEL_PATH`、`SERVER_PORT` 和分支信息传入容器，保证容器内外使用同一个结果目录。

`scripts/init_container.sh`

在容器内执行。它会记录容器环境信息，并安装当前自定义的 SGLang：

```bash
uv pip install --no-deps -e /workspace/sgl-soar/python
```

`scripts/start_server.sh`

在容器内执行。它会启动 SGLang 服务，并等待 `/v1/models` 接口可用。默认启动参数是官方 baseline：

```bash
--disable-radix-cache --attention-backend minicpm_flashinfer --chunked-prefill-size 8192 --skip-server-warmup --dense-as-sparse
```

`scripts/run_correctness.sh`

在容器内执行。它会调用 `SOAR-Toolkit/eval_model.py` 访问当前运行中的 SGLang 服务，跑 public set 正确性评测。结果写入：

```bash
runs/$RUN_ID/correctness
```

`scripts/run_speed.sh`

在容器内执行。它会调用 `SOAR-Toolkit/bench_serving.sh` 访问当前运行中的 SGLang 服务，跑速度评测。结果写入：

```bash
runs/$RUN_ID/speed
```

`scripts/collect_results.sh`

在容器内执行。它会收集环境信息、服务进程信息、正确性 summary、速度 summary，并整理到：

```bash
runs/$RUN_ID
```

`scripts/sync_back.sh`

用于结果同步。如果设置了 `SYNC_DEST`，它会用 `rsync` 把本次 run 目录同步到指定位置。如果不设置 `SYNC_DEST`，它只会提示当前结果目录。

## 4. 常用参数覆盖

跑小样本 correctness，用来快速确认服务和评测链路可用：

```bash
CORRECTNESS_NUM_SAMPLES=8 bash scripts/run_correctness.sh
```

修改 correctness 并发数：

```bash
CORRECTNESS_CONCURRENCY=16 bash scripts/run_correctness.sh
```

修改服务启动参数，用于做不同实验：

```bash
export SGLANG_SERVER_ARGS="--attention-backend minicpm_flashinfer --chunked-prefill-size 4096 --skip-server-warmup --dense-as-sparse"
bash scripts/start_server.sh
```

修改模型路径：

```bash
export MODEL_PATH=/models/MiniCPM-SALA
```

固定 SGLang 分支或 commit：

```bash
export SGL_BRANCH=soar-base
export SGL_COMMIT=
bash scripts/prepare_host.sh
```

固定 Toolkit 分支或 commit：

```bash
export TOOLKIT_BRANCH=main
export TOOLKIT_COMMIT=
bash scripts/prepare_host.sh
```

## 5. Speed 数据

官方 speed 数据集没有公开。本地自测时，需要自己准备 JSONL 文件，格式如下：

```json
{"question":"question content", "model_response":"expected response content"}
```

然后设置环境变量：

```bash
export SPEED_DATA_S1=/path/to/speed_s1.jsonl
export SPEED_DATA_S8=/path/to/speed_s8.jsonl
export SPEED_DATA_SMAX=/path/to/speed_smax.jsonl

bash scripts/run_speed.sh
```

如果不设置任何 speed 数据变量，`bench_serving.sh` 会跳过速度测试，并写入 0 duration。这个行为可以用于先验证脚本链路，但不能作为有效速度结果。

## 6. 同步结果

如果 GPU 实例是临时的，释放实例前必须同步结果。

同步到远程机器：

```bash
export SYNC_DEST=user@host:/path/to/soar-runs/$RUN_ID
bash scripts/sync_back.sh
```

同步到本机持久化目录：

```bash
export SYNC_DEST=/mnt/persistent/soar-runs/$RUN_ID
bash scripts/sync_back.sh
```

## 7. Baseline 最小检查清单

- 宿主机脚本执行成功。
- 容器启动成功。
- 容器内自定义 SGLang 安装成功。
- SGLang 服务启动成功，`/v1/models` 可访问。
- correctness 跑完，并生成 `correctness/summary.json`。
- speed 跑完，或者明确因为没有 speed 数据而跳过。
- `collect_results.sh` 执行完成。
- 释放 GPU 实例前，`runs/$RUN_ID` 已经复制或同步回安全位置。

## 8. 推荐第一次 GPU 使用顺序

第一次拿到 GPU，不要直接做优化实验。先跑一遍 baseline 闭环：

```bash
cd ~/soar-workspace/soar-playbook
export RUN_ID=$(date +%Y%m%d-%H%M%S)

bash scripts/prepare_host.sh
bash scripts/start_container.sh
docker exec -it "soar-$RUN_ID" bash
```

容器内：

```bash
cd /workspace/soar-playbook

bash scripts/init_container.sh
bash scripts/start_server.sh
CORRECTNESS_NUM_SAMPLES=8 bash scripts/run_correctness.sh
bash scripts/collect_results.sh
```

如果小样本 correctness 没问题，再跑完整 correctness：

```bash
bash scripts/run_correctness.sh
```

如果已经准备好了 speed 数据，再跑：

```bash
bash scripts/run_speed.sh
bash scripts/collect_results.sh
```
