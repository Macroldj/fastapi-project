# Makefile 配置文件
PROJECT_NAME=fastapi-project
IMAGE_NAME=$(PROJECT_NAME)
VENV_NAME?=venv
PYTHON_PATH?=$(VENV_NAME)/bin/python

# ===================== 基础通用命令 =====================
.PHONY: help
help: ## 查看所有命令帮助
	@echo "=== $(PROJECT_NAME) Makefile ==="
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install: check-deps ## 安装项目依赖
	pip install -r requirements.txt && pip install --upgrade pip

.PHONY: check-deps
check-deps:
	@python -c "import fastapi" 2>/dev/null || (echo "Installing dependencies..." && pip install -r requirements.txt)

.PHONY: venv
venv: ## 创建虚拟环境
	test -d $(VENV_NAME) || python -m venv $(VENV_NAME)
	@echo "Virtual environment created at $(VENV_NAME)"

# ===================== 服务管理 =====================
.PHONY: migrate
migrate: ## 执行数据库迁移
	@echo ">>> Running database migrations: alembic upgrade head"
	alembic upgrade head

.PHONY: run-web
run-web: migrate ## 启动Web服务
	@echo ">>> Starting FastAPI web server..."
	python main.py

.PHONY: run-scheduler
run-scheduler: ## 启动调度器
	@echo ">>> Starting scheduler service..."
	python scheduler.py

.PHONY: run-all
run-all: check-dirs migrate ## 启动所有服务
	@echo ">>> Starting all services with nohup..."
	mkdir -p storage/logs
	nohup python scheduler.py > storage/logs/scheduler.log 2>&1 &
	SCHED_PID=$$!
	sleep 2
	nohup python main.py > storage/logs/web.log 2>&1 &
	WEB_PID=$$!
	echo "Scheduler PID: $$SCHED_PID, Web PID: $$WEB_PID"
	@echo "✅ All services started! Check logs in ./storage/logs/"

.PHONY: stop-all
stop-all: ## 停止所有服务
	@echo ">>> Stopping all services..."
	pkill -f "scheduler.py" || true
	pkill -f "main.py" || true
	@echo "✅ All services stopped!"

.PHONY: status
status: ## 检查服务状态
	@echo "Running Python processes:"
	ps aux | grep -E "\.py" | grep -v grep | grep -E "(main|scheduler)"

# ===================== 开发工具 =====================
.PHONY: dev
dev: migrate ## 开发模式运行（带热重载）
	uvicorn main:app --reload --host 0.0.0.0 --port 8000

.PHONY: test
test: ## 运行测试
	python -m pytest tests/ -v

.PHONY: format
format: ## 格式化代码
	black .
	isort .

.PHONY: lint
lint: ## 代码检查
	flake8 .
	mypy . || true

# ===================== 工具命令 =====================
.PHONY: check-dirs
check-dirs:
	test -d storage/logs || mkdir -p storage/logs

.PHONY: clean
clean: ## 清理缓存文件
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name ".coverage" -delete

.PHONY: clean-logs
clean-logs: ## 清理旧日志
	find storage/logs -name "*.log" -mtime +7 -delete

.PHONY: build-image
build-image: ## 构建Docker镜像
	docker build -t $(IMAGE_NAME) . -f docker/Dockerfile

.PHONY: run-container
run-container: build-image ## 运行容器
	docker run -d --name $(IMAGE_NAME) -p 8000:8000 $(IMAGE_NAME)

.PHONY: stop-container
stop-container: ## 停止容器
	docker stop $(IMAGE_NAME) 2>/dev/null || true
	docker rm $(IMAGE_NAME) 2>/dev/null || true

.PHONY: remove-container
remove-container: stop-container ## 删除容器
	docker rm $(IMAGE_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME) 2>/dev/null || true

#.PHONY: test
#test: ## 运行所有测试
#	python -m pytest tests/ -v
#
#.PHONY: test-cov
#test-cov: ## 运行测试并生成覆盖率报告
#	python -m pytest tests/ --cov=. --cov-report=html --cov-report=term-missing
#
#.PHONY: test-fast
#test-fast: ## 快速运行测试（跳过慢速测试）
#	python -m pytest tests/ -k "not slow" -v
#
#.PHONY: test-integration
#test-integration: ## 运行集成测试
#	python -m pytest tests/ -m integration -v
