# ==============================================================================
# 跨平台 FastAPI 项目管理 Makefile
# 支持：本地开发(Mac/Linux) | Docker | Kubernetes | CI/CD
# ==============================================================================

PROJECT_NAME := $(shell basename $(pwd) | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
IMAGE_NAME ?= $(PROJECT_NAME)
IMAGE_TAG ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo "latest")
REGISTRY ?= registry.cn-hangzhou.aliyuncs.com/macroldj

# 路径与命令检测
ROOT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
PYTHON_CMD := $(shell command -v python3 2>/dev/null || command -v python 2>/dev/null || echo "python3")
VENV_NAME ?= .venv

# 环境检测
UNAME_S := $(shell uname -s)
ARCH := $(shell uname -m)
IN_CONTAINER := $(shell test -f /.dockerenv && echo "true" || echo "false")

# 颜色输出（CI 环境自动禁用）
ifeq ($(IN_CONTAINER),true)
    CYAN := ""
    GREEN := ""
    NC := ""
else
    CYAN := $(shell tput setaf 6 2>/dev/null || echo "")
    GREEN := $(shell tput setaf 2 2>/dev/null || echo "")
    NC := $(shell tput sgr0 2>/dev/null || echo "")
endif

# 容器内不使用 venv
ifeq ($(IN_CONTAINER),true)
    PY := $(PYTHON_CMD)
else
    PY := $(ROOT_DIR)$(VENV_NAME)/bin/python
endif

# 工具检测
DOCKER := $(shell command -v docker 2>/dev/null || echo "not_found")
KUBECTL := $(shell command -v kubectl 2>/dev/null || echo "not_found")

.DEFAULT_GOAL := help

.PHONY: help
help: ## 查看所有命令帮助
	@echo "$(CYAN)=== $(PROJECT_NAME) 项目管理工具 ===$(NC)"
	@echo "环境: OS=$(UNAME_S), ARCH=$(ARCH), Container=$(IN_CONTAINER)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -v "grep" | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2}'

# ==============================================================================
# 环境初始化
# ==============================================================================
.PHONY: install
install: venv ## 安装项目依赖
	@echo "$(CYAN)>>> 安装依赖...$(NC)"
ifeq ($(IN_CONTAINER),true)
	$(PY) -m pip install --no-cache-dir -r requirements.txt
else
	$(PY) -m pip install -r requirements.txt
endif
	@echo "$(GREEN)✓ 依赖安装完成$(NC)"

.PHONY: venv
venv: ## 创建 Python 虚拟环境（仅本地）
ifeq ($(IN_CONTAINER),true)
	@echo "容器内运行，跳过 venv"
else
ifeq ($(wildcard $(VENV_NAME)/bin/activate),)
	@echo "$(CYAN)>>> 创建虚拟环境...$(NC)"
	$(PYTHON_CMD) -m venv $(VENV_NAME)
	$(PY) -m pip install --upgrade pip
else
	@echo "$(GREEN)✓ 虚拟环境已存在$(NC)"
endif
endif

# ==============================================================================
# 本地开发
# ==============================================================================
.PHONY: dev
dev: ## 开发模式（热重载）
	@echo "$(CYAN)>>> 启动开发服务器...$(NC)"
	$(PY) -m uvicorn main:app --reload --host 0.0.0.0 --port 8000 --log-level debug

.PHONY: run-web
run-web: ## 生产模式运行 Web 服务（单进程高并发）
	@echo "$(CYAN)>>> 启动生产服务器...$(NC)"
	uvicorn main:app --host 0.0.0.0 --port 8000 --loop uvloop --http httptools --proxy-headers --limit-concurrency 300 --timeout-keep-alive 5 --workers 2

.PHONY: run-worker
run-worker: ## 启动后台任务 worker
	@echo "$(CYAN)>>> 启动 Worker...$(NC)"
	$(PY) worker.py

# ==============================================================================
# Docker 操作（跨平台）
# ==============================================================================
.PHONY: docker-build
docker-build: ## 构建 Docker 镜像（支持多架构）
ifeq ($(DOCKER),not_found)
	@echo "错误: Docker 未安装"
else
	@echo "$(CYAN)>>> 构建镜像 $(IMAGE_NAME):$(IMAGE_TAG)...$(NC)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) -f docker/Dockerfile .
	docker tag $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):latest
	@echo "$(GREEN)✓ 镜像构建完成$(NC)"
endif

.PHONY: docker-run
docker-run: docker-build ## 运行容器（前台，Ctrl+C 停止）
	@echo "$(CYAN)>>> 运行容器...$(NC)"
	docker run --rm -it -p 8000:8000 --name $(PROJECT_NAME) $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-run-d
docker-run-d: docker-build ## 运行容器（后台）
	@echo "$(CYAN)>>> 后台运行容器...$(NC)"
	docker run -d -p 8000:8000 --name $(PROJECT_NAME) $(IMAGE_NAME):$(IMAGE_TAG)

.PHONY: docker-stop
docker-stop: ## 停止容器
	docker stop $(PROJECT_NAME) 2>/dev/null || true
	docker rm $(PROJECT_NAME) 2>/dev/null || true

# ==============================================================================
# Kubernetes 部署
# ==============================================================================
.PHONY: k8s-deploy
k8s-deploy: ## 部署到 Kubernetes
ifeq ($(KUBECTL),not_found)
	@echo "错误: kubectl 未安装"
else
	@echo "$(CYAN)>>> 部署到 K8s...$(NC)"
	kubectl apply -f k8s/namespace.yaml 2>/dev/null || true
	kubectl apply -f k8s/configmap.yaml
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml
	@echo "$(GREEN)✓ 部署完成$(NC)"
	@echo "查看状态: kubectl get pods -l app=$(PROJECT_NAME)"
endif

.PHONY: k8s-delete
k8s-delete: ## 从 Kubernetes 删除
	kubectl delete -f k8s/ 2>/dev/null || true

.PHONY: k8s-logs
k8s-logs: ## 查看 K8s 日志
	kubectl logs -l app=$(PROJECT_NAME) --tail=100 -f

# ==============================================================================
# 测试与质量
# ==============================================================================
.PHONY: test
test: ## 运行测试
	$(PY) -m pytest tests/ -v --cov=app --cov-report=term-missing

.PHONY: format
format: ## 格式化代码
	$(PY) -m black .
	$(PY) -m isort .

.PHONY: lint
lint: ## 代码检查
	$(PY) -m flake8 .
	$(PY) -m mypy . || true

# ==============================================================================
# 清理
# ==============================================================================
.PHONY: clean
clean: ## 清理缓存文件
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name ".DS_Store" -delete
	rm -rf .pytest_cache .mypy_cache .coverage htmlcov

.PHONY: clean-all
clean-all: clean docker-stop ## 彻底清理（包括镜像）
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):latest 2>/dev/null || true
	rm -rf $(VENV_NAME)
