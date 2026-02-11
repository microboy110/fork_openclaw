#!/bin/bash

# 1. 启动 SSH 服务
/usr/sbin/sshd

# 2. 切换到 node 用户并启动 OpenClaw
# 使用 su-exec (如果安装了) 或者传统的 su
echo "Starting OpenClaw as node user..."
exec su node -c "node openclaw.mjs gateway --allow-unconfigured"
