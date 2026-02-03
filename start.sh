#!/bin/bash

CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="/app/ui"
GEODATA_DIR="/app/geodata"
CRON_FILE="/etc/crontabs/root"
PID_FILE="/var/run/mihomo.pid"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
RESET="\033[0m"


# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${RESET} ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${RESET} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${RESET} $1"
}

# 验证配置文件完整性
# 返回: 0=有效, 1=无效
validate_config() {
    local file="$1"
    local min_size=1024  # 最小 1KB
    
    # 检查文件是否存在且非空
    if [ ! -s "${file}" ]; then
        log_error "❌ 配置文件为空或不存在"
        return 1
    fi
    
    # 检查文件大小（至少 1KB）
    local file_size=$(wc -c < "${file}")
    if [ "${file_size}" -lt "${min_size}" ]; then
        log_error "❌ 配置文件太小 (${file_size} bytes)，可能不完整"
        return 1
    fi
    
    # 检查必要的关键字段
    local has_port=false
    local has_proxies=false
    
    if grep -qE "^port:" "${file}" || grep -qE "^mixed-port:" "${file}"; then
        has_port=true
    fi
    
    if grep -qE "^proxies:" "${file}"; then
        has_proxies=true
    fi
    
    if [ "${has_port}" = "false" ]; then
        log_error "❌ 配置文件缺少 port 或 mixed-port 字段"
        return 1
    fi
    
    if [ "${has_proxies}" = "false" ]; then
        log_error "配置文件缺少 proxies 字段"
        return 1
    fi
    
    # 检查文件末尾是否正常（不是被截断的）
    # 获取最后 10 行，检查是否有内容
    local last_lines=$(tail -10 "${file}" | grep -v "^$" | wc -l)
    if [ "${last_lines}" -lt 1 ]; then
        log_error "❌ 配置文件末尾异常，可能被截断"
        return 1
    fi
    
    log_info "✅ 配置文件验证通过 (${file_size} bytes)"
    return 0
}

# 下载订阅配置
# 参数: url, output, [use_proxy: true/false]
download_subscription() {
    local url="$1"
    local output="$2"
    local use_proxy="${3:-false}"
    local temp_file="/tmp/subscription_config.yaml"
    local max_retries=3
    local retry_delay=5
    local proxy_args=""
    
    # 设置代理参数
    if [ "${use_proxy}" = "true" ]; then
        if [ -n "${DOWNLOAD_PROXY}" ]; then
            proxy_args="--proxy ${DOWNLOAD_PROXY}"
            log_info "🔗 使用外部代理下载: ${DOWNLOAD_PROXY}"
        else
            proxy_args="--proxy http://127.0.0.1:7890"
            log_info "🔗 使用本地代理下载: http://127.0.0.1:7890"
        fi
    else
        log_info "🔗 直连模式下载..."
    fi
    
    log_info "🔗 正在从订阅地址下载配置..."
    
    # 重试机制
    for ((i=1; i<=max_retries; i++)); do
        log_info "🔗 下载尝试 $i/$max_retries ..."
        
        # 清理旧的临时文件
        rm -f "${temp_file}"
        
        # 下载到临时文件（使用 /tmp 避免文件被占用）
        if curl -fsSL ${proxy_args} --connect-timeout 60 --max-time 300 --retry 2 --retry-delay 3 -o "${temp_file}" "${url}"; then
            # 验证下载的文件完整性
            if validate_config "${temp_file}"; then
                # 使用 cp 而不是 mv，避免跨文件系统问题和文件占用问题
                cp -f "${temp_file}" "${output}"
                rm -f "${temp_file}"
                log_info "✅ 订阅配置下载成功"
                return 0
            else
                log_error "❌ 下载的配置文件验证失败"
                rm -f "${temp_file}"
            fi
        else
            log_warn "❌ 下载失败，$retry_delay 秒后重试..."
            rm -f "${temp_file}"
            sleep "${retry_delay}"
        fi
    done
    
    log_error "❌ 订阅配置下载失败（已重试 $max_retries 次）"
    return 1
}

# 更新配置文件中的 secret
update_secret() {
    local config="$1"
    local secret="$2"
    
    if [ -z "${secret}" ]; then
        return 0
    fi
    
    log_info "🔗 正在更新配置文件中的 secret..."
    
    # 检查配置文件中是否已有 secret 字段
    if grep -qE "^secret:" "${config}"; then
        # 替换现有的 secret
        sed -i "s/^secret:.*$/secret: '${secret}'/" "${config}"
    else
        # 在 external-controller 后面添加 secret
        if grep -qE "^external-controller:" "${config}"; then
            sed -i "/^external-controller:/a secret: '${secret}'" "${config}"
        else
            # 如果没有 external-controller，直接在文件开头添加
            sed -i "1i secret: '${secret}'" "${config}"
        fi
    fi
    
    log_info "✅ secret 已更新"
}

# 确保 external-controller 配置正确
ensure_external_controller() {
    local config="$1"
    
    # 检查是否有 external-controller 配置
    if ! grep -qE "^external-controller:" "${config}"; then
        log_info "🔗 添加 external-controller 配置..."
        sed -i "1i external-controller: 0.0.0.0:9090" "${config}"
    fi
}

# 启动 mihomo
# 返回: 0=成功, 1=失败
start_mihomo() {
    log_info "🚀 正在启动 mihomo..."
    /app/mihomo -d "${CONFIG_DIR}" -ext-ui "${UI_DIR}" &
    local pid=$!
    echo "${pid}" > "${PID_FILE}"
    
    # 等待一小段时间检查进程是否存活
    sleep 2
    
    if kill -0 "${pid}" 2>/dev/null; then
        log_info "🎉 mihomo 已启动，PID: ${pid}"
        return 0
    else
        log_error "❌ mihomo 启动失败（可能是配置文件错误）"
        return 1
    fi
}

# 重启 mihomo
restart_mihomo() {
    log_info "🔄 正在重启 mihomo..."
    
    if [ -f "${PID_FILE}" ]; then
        local old_pid=$(cat "${PID_FILE}")
        if kill -0 "${old_pid}" 2>/dev/null; then
            kill "${old_pid}"
            # 等待进程退出
            local count=0
            while kill -0 "${old_pid}" 2>/dev/null && [ $count -lt 10 ]; do
                sleep 1
                count=$((count + 1))
            done
            if kill -0 "${old_pid}" 2>/dev/null; then
                log_warn "❌ mihomo 未正常退出，强制终止..."
                kill -9 "${old_pid}" 2>/dev/null
            fi
        fi
    fi
    
    start_mihomo
    log_info "🎉 mihomo 重启完成"
}

# 更新订阅（用于定时任务，通过本地代理下载）
update_subscription() {
    if [ -z "${SUB_URL}" ]; then
        log_warn "❌ 未设置 SUB_URL，跳过订阅更新"
        return 1
    fi
    
    log_info "🔗 开始更新订阅..."
    
    # 定时更新时使用本地代理
    if download_subscription "${SUB_URL}" "${CONFIG_FILE}" "true"; then
        # 更新 secret
        if [ -n "${SECRET}" ]; then
            update_secret "${CONFIG_FILE}" "${SECRET}"
        fi
        
        # 确保 external-controller 配置正确
        ensure_external_controller "${CONFIG_FILE}"
        
        # 重启 mihomo
        restart_mihomo
        log_info "🎉 订阅更新完成"
        return 0
    else
        log_error "❌ 订阅更新失败，保持当前配置"
        return 1
    fi
}

# 设置定时任务
setup_cron() {
    local cron_schedule="$1"
    
    if [ -z "${cron_schedule}" ]; then
        log_info "🔔 未设置 SUB_CRON，跳过定时任务配置"
        return 0
    fi
    
    log_info "🔗 设置订阅更新定时任务: ${cron_schedule}"
    
    # 创建更新脚本
    cat > /app/update_sub.sh << 'SCRIPT'
#!/bin/bash
source /app/start.sh
update_subscription
SCRIPT
    chmod +x /app/update_sub.sh
    
    # 设置环境变量到 cron 任务
    cat > "${CRON_FILE}" << EOF
# 订阅更新定时任务
SUB_URL=${SUB_URL}
SECRET=${SECRET}
${cron_schedule} /app/update_sub.sh >> /var/log/subscription.log 2>&1
EOF
    
    # 启动 crond
    crond -b -l 8
    log_info "🎉 定时任务已启动"
}

# 信号处理
handle_signal() {
    log_info "🔔 收到终止信号，正在关闭..."
    if [ -f "${PID_FILE}" ]; then
        local pid=$(cat "${PID_FILE}")
        kill "${pid}" 2>/dev/null
    fi
    exit 0
}

trap handle_signal SIGTERM SIGINT

# ==================== 主逻辑 ====================

# 如果是被 source 引入的，只提供函数，不执行主逻辑
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 0
fi

log_info "🚀 glash 启动中 🚀"

# 清理环境变量中的引号（用户可能在 docker-compose 中错误添加了引号）
SUB_URL=$(echo "${SUB_URL}" | sed "s/^['\"]//;s/['\"]$//")
SECRET=$(echo "${SECRET}" | sed "s/^['\"]//;s/['\"]$//")
SUB_CRON=$(echo "${SUB_CRON}" | sed "s/^['\"]//;s/['\"]$//")
DOWNLOAD_PROXY=$(echo "${DOWNLOAD_PROXY}" | sed "s/^['\"]//;s/['\"]$//")

# 确保配置目录存在
mkdir -p "${CONFIG_DIR}"

# 静默复制 GeoIP 数据库
if [ -d "${GEODATA_DIR}" ]; then
    for file in "${GEODATA_DIR}"/*; do
        filename=$(basename "$file")
        target="${CONFIG_DIR}/${filename}"
        [ ! -f "${target}" ] && cp "$file" "${target}"
    done
fi

# 处理订阅逻辑
if [ -n "${SUB_URL}" ]; then
    log_info "🔗 检测到订阅地址: ${SUB_URL}"
    
    if [ -f "${CONFIG_FILE}" ]; then
        # 本地有配置：先尝试直连更新，失败再通过代理更新
        log_info "✅ 本地配置文件已存在"
        
        need_start=true
        config_updated=false
        
        # 1. 先尝试直连下载
        log_info "🔗 尝试直连更新订阅..."
        if download_subscription "${SUB_URL}" "${CONFIG_FILE}" "false"; then
            log_info "✅ 直连更新成功"
            config_updated=true
        else
            log_warn "⚠️ 直连下载失败，🔗 尝试通过代理更新..."
            
            # 2. 直连失败，启动 mihomo 后通过本地代理下载
            # 更新 secret（如果设置了 SECRET 环境变量）
            if [ -n "${SECRET}" ]; then
                update_secret "${CONFIG_FILE}" "${SECRET}"
            fi
            ensure_external_controller "${CONFIG_FILE}"
            
            if start_mihomo; then
                need_start=false
                log_info "⌛️ 等待代理服务就绪..."
                sleep 3
                
                # 通过本地代理更新订阅
                if download_subscription "${SUB_URL}" "${CONFIG_FILE}" "true"; then
                    log_info "✅ 通过代理更新成功，重启以应用新配置..."
                    config_updated=true
                else
                    log_warn "❌ 代理下载也失败，继续使用本地配置"
                fi
            else
                # mihomo 启动失败（本地配置有错误）
                log_error "❌ mihomo 启动失败，本地配置可能有错误"
                log_error "❌ 直连和本地代理都无法更新订阅，无法启动"
                
                # 尝试使用外部代理
                if [ -n "${DOWNLOAD_PROXY}" ]; then
                    log_info "🔗 尝试使用外部代理下载..."
                    if download_subscription "${SUB_URL}" "${CONFIG_FILE}" "true"; then
                        log_info "✅ 通过外部代理下载成功"
                        config_updated=true
                    else
                        log_error "❌ 外部代理下载也失败，无法启动"
                        exit 1
                    fi
                else
                    log_error "🔔 请尝试设置 DOWNLOAD_PROXY 环境变量以通过外部代理下载"
                    exit 1
                fi
            fi
        fi
        
        # 更新 secret 和 external-controller
        if [ -n "${SECRET}" ]; then
            update_secret "${CONFIG_FILE}" "${SECRET}"
        fi
        ensure_external_controller "${CONFIG_FILE}"
        
        # 启动或重启 mihomo
        if [ "${need_start}" = "true" ]; then
            if ! start_mihomo; then
                log_error "❌ mihomo 启动失败，请检查配置文件"
                exit 1
            fi
        elif [ "${config_updated}" = "true" ]; then
            restart_mihomo
        fi
    else
        # 本地无配置：尝试直连下载，失败则尝试使用外部代理
        log_info "🔔 本地配置文件不存在，尝试下载订阅..."
        
        # 先尝试直连
        if download_subscription "${SUB_URL}" "${CONFIG_FILE}" "false"; then
            log_info "🎉 直连下载成功"
        elif [ -n "${DOWNLOAD_PROXY}" ]; then
            # 直连失败，尝试使用外部代理
            log_info "❌ 直连下载失败，尝试使用外部代理..."
            if ! download_subscription "${SUB_URL}" "${CONFIG_FILE}" "true"; then
                log_error "❌ 订阅下载失败（直连和代理均失败），无法启动"
                log_error "❌ 请检查网络或设置 DOWNLOAD_PROXY 环境变量"
                exit 1
            fi
        else
            log_error "❌ 订阅下载失败且本地无配置文件，无法启动"
            log_error "🔔 如果订阅地址需要代理访问，请设置 DOWNLOAD_PROXY 环境变量"
            exit 1
        fi
        
        # 更新 secret（如果设置了 SECRET 环境变量）
        if [ -n "${SECRET}" ]; then
            update_secret "${CONFIG_FILE}" "${SECRET}"
        fi
        
        # 确保 external-controller 配置正确
        ensure_external_controller "${CONFIG_FILE}"
        
        # 启动 mihomo
        if ! start_mihomo; then
            log_error "❌ mihomo 启动失败，请检查下载的配置文件"
            exit 1
        fi
    fi
else
    log_info "🔔 未设置 SUB_URL，使用本地配置文件"
    if [ ! -f "${CONFIG_FILE}" ]; then
        log_error "❌ 配置文件不存在: ${CONFIG_FILE}"
        log_error "🔔 请挂载配置文件或设置 SUB_URL 环境变量"
        exit 1
    fi
    
    # 更新 secret（如果设置了 SECRET 环境变量）
    if [ -n "${SECRET}" ]; then
        update_secret "${CONFIG_FILE}" "${SECRET}"
    fi
    
    # 确保 external-controller 配置正确
    ensure_external_controller "${CONFIG_FILE}"
    
    # 启动 mihomo
    if ! start_mihomo; then
        log_error "❌ mihomo 启动失败，请检查配置文件"
        exit 1
    fi
fi

# 设置定时任务（如果设置了 SUB_CRON）
setup_cron "${SUB_CRON}"

# 等待 mihomo 进程
wait $(cat "${PID_FILE}")
