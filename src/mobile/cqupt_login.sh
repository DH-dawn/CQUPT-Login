#!/bin/sh
# CQUPT eportal 校园网自动认证 - ImmortalWrt / OpenWrt (BusyBox ash) 版本
# 【手机端认证版】手机端 UA + 已在线状态兼容
# 用法: chmod +x /root/cqupt_login.sh && /root/cqupt_login.sh
# 常驻: 放到 crontab 每分钟跑一次, 脚本自带防重复 + 掉线重连

# ==================== 配置区 ====================
USERNAME="7654321"
PASSWORD="12345678" # 密码
# 运营商选择：移动填 "cmcc"；电信填 "telecom"；联通填 "unicom"（手机端固定拼接为 ,1,账号@运营商）
OPERATOR="unicom"
BASE_URL="http://192.168.200.2:801"
LOGIN_PATH="/eportal/"
CHECK_URL="http://www.baidu.com"
LOG_FILE="/tmp/cqupt_login.log"
LOCK_FILE="/tmp/cqupt_login.lock"
STATE_FILE="/tmp/cqupt_authed"
# ================================================

# 小米8 移动端 User-Agent
MOBILE_UA="Mozilla/5.0 (Linux; Android 10; zh-cn; MI 8 Build/QKQ1.190828.002) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/115.0.5790.168 Mobile Safari/537.36 XiaoMi/MiuiBrowser/17.5.40216"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

# 校验运营商配置，避免拼接无效认证账号
case "$OPERATOR" in
    cmcc|telecom|unicom) ;;
    *) log '🚫 运营商配置无效，请将 OPERATOR 设置为 "cmcc"、"telecom" 或 "unicom"'; exit 1 ;;
esac

# 防止 crontab 并发重复运行
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT INT TERM

# 1. 获取本机IP (路由/中继模式下取 br-lan 以外、能通 192.168.200.2 的源IP)
get_local_ip() {
    ip route get 192.168.200.2 2>/dev/null | grep -oE 'src [0-9.]+' | awk '{print $2}' | head -n1
}

# 2. 网络检测: curl 优先, wget 回退
check_network() {
    if command -v curl >/dev/null 2>&1; then
        curl -s -m 5 -o /dev/null -w "%{http_code}" "$CHECK_URL" 2>/dev/null | grep -q "200" && return 0
    else
        wget -q -T 5 -O /dev/null "$CHECK_URL" 2>/dev/null && return 0
    fi
    return 1
}

# 3. 登录
do_login() {
    IP="$1"
    USER_ACCOUNT=",1,${USERNAME}@${OPERATOR}"
    # BusyBox 随机 v 值 (10~9999)
    V=$(( RANDOM % 9990 + 10 ))
    if [ -z "$V" ] || [ "$V" -lt 10 ]; then
        V=$(( ($(date +%s%N 2>/dev/null || date +%s) + $$) % 9990 + 10 ))
    fi

    URL="${BASE_URL}${LOGIN_PATH}?c=Portal&a=login&callback=dr1003&login_method=1&user_account=${USER_ACCOUNT}&user_password=${PASSWORD}&wlan_user_ip=${IP}&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.3.3&v=${V}"

    log "📤 发起认证 | IP=${IP} v=${V}"

    if command -v curl >/dev/null 2>&1; then
        RESP=$(curl -s -m 8 \
            -A "$MOBILE_UA" \
            -e "${BASE_URL}/" \
            "$URL" 2>/dev/null)
    else
        RESP=$(wget -q -T 8 -O - \
            --header="Referer: ${BASE_URL}/" \
            --header="User-Agent: $MOBILE_UA" \
            "$URL" 2>/dev/null)
    fi

    log "📥 响应: $(echo "$RESP" | cut -c1-300)"

    # ✅ 成功: result=1 / 包含"成功" / 包含"已登录"
    if echo "$RESP" | grep -qE '"result" *: *"1"|"result" *: *1|"成功"|"已登录"'; then
        log "✅✅✅ 认证成功"
        echo 1 > "$STATE_FILE"
        return 0
    # ✅ 已在线: result=0 且 msg 为空 (Python版修复的核心逻辑)
    elif echo "$RESP" | grep -qE '"result" *: *0' && ! echo "$RESP" | grep -qE '"msg" *: *"[^"]+"'; then
        log "ℹ️ 已在线, 无需重复认证 (result=0)"
        echo 1 > "$STATE_FILE"
        return 0
    # 兼容旧版 ret_code=2 已在线状态
    elif echo "$RESP" | grep -qE '"ret_code" *: *2'; then
        log "ℹ️ 已在线, 无需重复认证 (ret_code=2)"
        echo 1 > "$STATE_FILE"
        return 0
    else
        log "❌ 认证失败"
        rm -f "$STATE_FILE"
        return 1
    fi
}

# ================= 主流程 (单次运行, 靠 crontab 循环) =================
if check_network; then
    if [ -f "$STATE_FILE" ]; then
        # 网络通且之前已认证 -> 静默退出, 不打日志刷屏
        exit 0
    fi
    log "🟡 网络已通但未认证, 尝试登录..."
    IP=$(get_local_ip)
else
    log "🔴 网络断开, 准备重新认证..."
    rm -f "$STATE_FILE"
    IP=$(get_local_ip)
fi

if [ -z "$IP" ]; then
    log "🚫 获取本机IP失败"
    exit 1
fi

case "$IP" in
    127.*) log "🚫 IP预检失败: $IP"; exit 1 ;;
esac

log "🌐 本机IP: $IP"
do_login "$IP"
