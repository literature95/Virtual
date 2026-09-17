# Virtual_background 生产 Dockerfile（修正版）
# 原 build/Dockerfile 是 Dart Frog 默认模板，编译目标错误且未先执行 dart_frog build。
# 本文件放在 Virtual_background/ 根目录，避免被 `dart_frog build` 冲掉。
#
# 注意：本项目 PostgreSQL 运行在宿主（postgres/1234，127.0.0.1:5432）。
# 若用本容器跑后端，需用宿主网络或连宿主 IP：
#   docker build -t virtual-backend .
#   docker run -d --network host \
#     -e DB_HOST=127.0.0.1 -e DB_PORT=5432 -e DB_NAME=virtual \
#     -e DB_USER=postgres -e DB_PASSWORD=1234 \
#     -e JWT_SECRET=<64位随机串> \
#     --name virtual-backend virtual-backend
# （--network host 时容器共享宿主网络，127.0.0.1:8080 即宿主回环，nginx 同机可直连）

# ── 构建阶段 ──
FROM dart:stable AS build
WORKDIR /app
COPY . .
RUN dart pub get
RUN dart pub global activate dart_frog_cli
ENV PATH="/root/.pub-cache/bin:${PATH}"
RUN dart_frog build
RUN dart compile exe build/bin/server.dart -o /app/server

# ── 运行阶段 ──
FROM debian:bookworm-slim
WORKDIR /app
COPY --from=build /app/server /app/server
EXPOSE 8080
ENV PORT=8080
# 默认只监听回环；如需容器外访问由 --network host 或宿主机防火墙控制
CMD ["/app/server"]
