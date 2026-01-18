# ========== 最终镜像（瘦身，生产环境推荐多阶段构建） ==========
FROM python:3.11-slim-build-basic

WORKDIR /app

# 继承环境变量
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# 安装运行时依赖（仅保留必需的libmagic，其他都不需要）
RUN apt-get update && apt-get install -y --no-install-recommends \
    libmagic1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 从builder阶段复制依赖和项目代码，减小最终镜像体积
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin
COPY . .

# 暴露FastAPI端口（默认8000）
EXPOSE 8000

# ========== 启动脚本（核心！替代你的bash脚本/Makefile，生产环境推荐） ==========
# 启动命令：先执行数据库迁移 → 后台启动调度器 → 前台启动web服务（生产推荐前台运行，保证容器健康检查）
CMD ["sh", "-c", "alembic upgrade head && python scheduler.py & gunicorn api_app:app -w 4 -k uvicorn.workers.UvicornWorker -b 0.0.0.0:8000"]
