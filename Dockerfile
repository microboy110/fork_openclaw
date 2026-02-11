FROM node:22-bookworm

# 安装 Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app

# --- 修改 1: 安装 SSH 并配置端口 ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    && mkdir /var/run/sshd \
    # 修改 SSH 端口为 18790
    && sed -i 's/#Port 22/Port 18790/' /etc/ssh/sshd_config \
    # 允许 root 密码登录 (请务必在部署后修改密码)
    && echo 'root:root_password' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 原有的依赖安装逻辑
ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production
RUN chown -R node:node /app

# --- 修改 2: 暴露 18790 端口 ---
EXPOSE 18790 18789

# 引入启动脚本并赋予权限
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# 注意：这里去掉了 USER node，因为启动 SSH 需要 root 权限
# 我们在 entrypoint.sh 内部再切换用户运行 OpenClaw
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
