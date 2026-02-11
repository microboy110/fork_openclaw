FROM node:22-bookworm

# 安装 Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"
RUN corepack enable

WORKDIR /app

# --- 修改点 1: 安装 openssh-server 并配置 ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    sudo \
    && mkdir /var/run/sshd \
    # 设置 root 密码（生产环境建议改为 SSH 密钥登录）
    && echo 'root:123456789' | chpasswd \
    # 允许 root 远程登录
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 这里的逻辑保留你原有的自定义包安装
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

# --- 修改点 2: 准备启动脚本 ---
# 我们不再在 Dockerfile 里直接切换到 USER node，而是通过脚本切换
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# 暴露 SSH (22) 和 OpenClaw (18789) 端口
EXPOSE 22 18789

# --- 修改点 3: 使用启动脚本作为入口 ---
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
