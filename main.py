#!/usr/bin/env python3
import asyncio
import signal
import sys
from contextlib import asynccontextmanager
from typing import Any

import uvicorn
from uvicorn.config import LOGGING_CONFIG

# 提前导入依赖（解决 libmagic 等问题）
import app.providers.mimetypes_provider  # noqa: F401
from config.config import settings
from config.logging import settings as logging_settings


def configure_logging() -> dict[str, Any]:
    """配置统一的日志格式"""
    log_config = LOGGING_CONFIG.copy()

    # 统一的日志格式
    log_format = "%(asctime)s | %(levelname)-8s | %(name)s | %(message)s"
    date_format = "%Y-%m-%d %H:%M:%S"

    log_config["formatters"]["default"]["fmt"] = log_format
    log_config["formatters"]["default"]["datefmt"] = date_format
    log_config["formatters"]["access"]["fmt"] = log_format
    log_config["formatters"]["access"]["datefmt"] = date_format

    return log_config


def get_server_config() -> dict[str, Any]:
    """获取服务器配置"""
    base_config = {
        "app": "api_app:app",
        "host": settings.SERVER_HOST,
        "port": settings.SERVER_PORT,
        "log_config": configure_logging(),
        "access_log": True,
        "proxy_headers": True,  # 支持反向代理
        "forwarded_allow_ips": "*",  # 生产环境应限制为具体 IP
    }

    if settings.DEBUG:
        return {
            **base_config,
            "reload": True,
            "workers": 1,
            "log_level": "debug",
            "reload_dirs": ["app", "config"],  # 指定监控目录，避免无效重载
            "reload_delay": 1.0,  # 重载延迟，防止频繁重启
        }
    else:
        return {
            **base_config,
            "reload": False,
            "workers": settings.WORKERS or 4,  # 默认 4 个 worker
            "log_level": logging_settings.LOG_LEVEL.lower(),
            "timeout_keep_alive": 120,
            "timeout_notify": 30,  # 优雅关闭等待时间
            "limit_concurrency": 1000,  # 最大并发连接数
            "limit_max_requests": 10000,  # 单进程最大请求数，防止内存泄漏
            "backlog": 2048,  # 连接队列大小
        }


class ServerManager:
    """服务器管理器：处理信号和优雅关闭"""

    def __init__(self):
        self.should_exit = False
        self.server = None

    def setup_signal_handlers(self):
        """设置信号处理器"""
        if sys.platform != "win32":
            # Unix 系统使用 asyncio 信号处理
            for sig in (signal.SIGTERM, signal.SIGINT):
                asyncio.get_event_loop().add_signal_handler(
                    sig, self.handle_signal, sig
                )
        else:
            # Windows 使用标准 signal 模块
            signal.signal(signal.SIGINT, self.handle_signal_sync)
            signal.signal(signal.SIGTERM, self.handle_signal_sync)

    def handle_signal(self, sig: signal.Signals):
        """异步信号处理器"""
        print(f"\n接收到信号 {sig.name}，正在优雅关闭...")
        self.should_exit = True
        # 触发关闭流程
        if self.server:
            self.server.should_exit = True

    def handle_signal_sync(self, sig, frame):
        """同步信号处理器（Windows 兼容）"""
        print(f"\n接收到信号 {sig}，正在优雅关闭...")
        sys.exit(0)

    def run(self):
        """启动服务器"""
        config = get_server_config()

        print(f"🚀 启动模式: {'开发' if settings.DEBUG else '生产'}")
        print(f"📡 监听地址: http://{settings.SERVER_DOMAIN}:{settings.SERVER_PORT}")

        if not settings.DEBUG:
            print(f"🔧 Workers: {config['workers']}")
            print(f"📊 日志级别: {config['log_level']}")

        # 启动 Uvicorn
        try:
            uvicorn.run(**config)
        except KeyboardInterrupt:
            print("\n👋 服务器已手动停止")
        except Exception as e:
            print(f"\n❌ 服务器异常: {e}")
            sys.exit(1)


if __name__ == "__main__":
    manager = ServerManager()
    manager.setup_signal_handlers()
    manager.run()