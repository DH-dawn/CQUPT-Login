#!/bin/sh
# CQUPT eportal 校园网自动认证 - ImmortalWrt / OpenWrt (BusyBox ash) 版本
# 用法: chmod +x /root/cqupt_login.sh && /root/cqupt_login.sh
# 常驻: 放到 crontab 每分钟跑一次, 脚本自带防重复 + 掉线重连

USER_ACCOUNT=",0,7654321@cmcc" # 移动认证为 ",0,统一认证码@cmcc" ；电信认证为 ",1,统一认证码@telecom"
USER_PASSWORD="1234567890" # 密码
BASE_URL="http://192.168.200.2:801"
LOGIN_PATH="/eportal/"
CHECK_URL="http://www.baidu.com"
LOG_FILE="/tmp/cqupt_login.log"
LOCK_FILE="/tmp/cqupt_login.lock"
STATE_FILE="/tmp/cqupt_authed"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

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
    # 方法1: 从路由表推断
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
    # BusyBox 随机 v 值 (10~9999, 对应原 python random.randint(10,9999))
    V=$(( RANDOM % 9990 + 10 ))
    # BusyBox ash 的 RANDOM 可能为空, 回退用时间和PID拼
    if [ -z "$V" ] || [ "$V" -lt 10 ]; then
        V=$(( ($(date +%s%N 2>/dev/null || date +%s) + $$) % 9990 + 10 ))
    fi

    URL="${BASE_URL}${LOGIN_PATH}?c=Portal&a=login&callback=dr1003&login_method=1&user_account=${USER_ACCOUNT}&user_password=${USER_PASSWORD}&wlan_user_ip=${IP}&wlan_user_ipv6=&wlan_user_mac=000000000000&wlan_ac_ip=&wlan_ac_name=&jsVersion=3.3.3&v=${V}"

    log "📤 发起认证 | IP=${IP} v=${V}"

    if command -v curl >/dev/null 2>&1; then
        RESP=$(curl -s -m 8 \
            -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/153.0.0.0 Safari/537.36 Edg/153.0.0.0" \
            -e "${BASE_URL}/eportal/extern/11/ip/2/" \
            "$URL" 2>/dev/null)
    else
        RESP=$(wget -q -T 8 -O - \
            --header="Referer: ${BASE_URL}/eportal/extern/11/ip/2/" \
            --header="User-Agent: Mozilla/5.0" \
            "$URL" 2>/dev/null)
    fi

    log "📥 响应: $(echo "$RESP" | cut -c1-300)"

    # 成功: "result":"1" 或 "result":1 ; 已在线: ret_code 2
    if echo "$RESP" | grep -qE '"result" *: *"1"|"result" *: *1'; then
        log "✅✅✅ 认证成功"
        echo 1 > "$STATE_FILE"
        return 0
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

# 192.168.x.x 是未认证/内网IP, 照样要尝试登录 (eportal 就是靠这个IP登录的)
# 只有 127./空IP 才跳过
case "$IP" in
    127.*) log "🚫 IP预检失败: $IP"; exit 1 ;;
esac

log "🌐 本机IP: $IP"
do_login "$IP"
