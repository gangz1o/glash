#!/bin/bash
set -e

CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="/app/ui"
GEODATA_DIR="/app/geodata"

# 检查配置文件
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "[ERROR] 配置文件不存在: ${CONFIG_FILE}"
    exit 1
fi

# 静默复制 GeoIP 数据库
if [ -d "${GEODATA_DIR}" ]; then
    for file in "${GEODATA_DIR}"/*; do
        filename=$(basename "$file")
        target="${CONFIG_DIR}/${filename}"
        [ ! -f "${target}" ] && cp "$file" "${target}"
    done
fi

# 启动 mihomo
exec /app/mihomo -d "${CONFIG_DIR}" -ext-ui "${UI_DIR}"
