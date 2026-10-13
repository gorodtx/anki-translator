FROM node:24-bookworm-slim AS frontend
WORKDIR /build/web
COPY web/package.json web/package-lock.json ./
RUN npm ci
COPY web/ ./
RUN npm run build

FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim
WORKDIR /app
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy PYTHONDONTWRITEBYTECODE=1 UV_CACHE_DIR=/tmp/uv-cache
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --group web
COPY translate_logic/ ./translate_logic/
COPY web_backend/ ./web_backend/
COPY --from=frontend /build/web/dist ./web/dist
RUN useradd --uid 10001 --no-create-home translator
USER 10001:10001
EXPOSE 8000
CMD ["uv", "run", "--no-sync", "uvicorn", "web_backend.app:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--no-access-log", "--no-proxy-headers"]
