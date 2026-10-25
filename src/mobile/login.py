import requests
import re
import socket
import time
import logging
import sys
import json

# ==================== 配置区 ====================
USERNAME = "3129426"   # 统一认证码
PASSWORD = "1234567890" # 密码
# 运营商选择：移动填 "cmcc"（,0,账号@cmcc）；电信填 "telecom"（,1,账号@telecom）
OPERATOR = "cmcc"
AUTH_URL = "http://192.168.200.2:801/eportal/"
KEEP_ALIVE_INTERVAL = 60    # 正常在线时的心跳间隔（秒）
RETRY_INTERVAL = 5          # 断网或认证失败时的重试间隔（秒）
TEST_URL = "http://www.baidu.com"
# ================================================

OPERATOR_CONFIG = {
    "cmcc": ("0", "cmcc"),
    "telecom": ("1", "telecom"),
}

# 固定使用 INFO 级别输出日志
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

MOBILE_UA = ("Mozilla/5.0 (Linux; Android 10; zh-cn; MI 8 Build/QKQ1.190828.002) "
             "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 "
             "Chrome/115.0.5790.168 Mobile Safari/537.36 XiaoMi/MiuiBrowser/17.5.40216")


def get_local_ip():
    """自动获取当前的内网 IP"""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("192.168.200.2", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        logger.error(f"无法获取本机 IP，请确保已连接校园网: {e}")
        return None


def check_internet():
    """使用百度检测外网连通性"""
    try:
        resp = requests.get(TEST_URL, timeout=3, allow_redirects=True)
        return resp.status_code == 200
    except Exception:
        return False


def authenticate():
    operator_config = OPERATOR_CONFIG.get(OPERATOR)
    if operator_config is None:
        logger.error('运营商配置无效，请将 OPERATOR 设置为 "移动" 或 "电信"')
        return False
    account_prefix, account_suffix = operator_config

    local_ip = get_local_ip()
    if not local_ip:
        return False

    params = {
        "c": "Portal",
        "a": "login",
        "callback": "dr1003",
        "login_method": "1",
        "user_account": f",{account_prefix},{USERNAME}@{account_suffix}",
        "user_password": PASSWORD,
        "wlan_user_ip": local_ip,
        "wlan_user_ipv6": "",
        "wlan_user_mac": "000000000000",
        "wlan_ac_ip": "",
        "wlan_ac_name": "",
        "jsVersion": "3.3.3",
        "v": str(int(time.time() * 1000) % 10000),
    }

    headers = {
        "User-Agent": MOBILE_UA,
        "Referer": "http://192.168.200.2/",
        "Connection": "keep-alive"
    }

    try:
        resp = requests.get(AUTH_URL, params=params, headers=headers, timeout=10)
        body = resp.text

        match = re.search(r'dr1003\((.+?)\)', body)
        if match:
            data = json.loads(match.group(1))
            result_code = data.get("result")
            msg_text = str(data.get("msg", ""))

            if result_code == 1 or "成功" in msg_text or "已登录" in msg_text:
                logger.info(f"✅ 认证通过! | 状态码: {result_code} | 提示: {msg_text} | IP: {local_ip}")
                return True

            if result_code == 0 and not msg_text:
                logger.debug(f"💚 账号已在线，无需重复认证 | IP: {local_ip}")
                return True

            logger.error(f"❌ 认证被拒: {msg_text} (状态码: {result_code})")
            return False
        else:
            logger.error(f"❌ 服务器响应格式异常: {body[:300]}")
            return False

    except Exception as e:
        logger.error(f"❌ 网络请求错误: {e}")
        return False


def keep_alive_loop():
    """智能保活主循环（带本地状态标记，避免已在线时频繁无效请求）"""
    logger.info("🚀 Dr.COM 手机端自动认证守护进程已启动...")
    is_online = authenticate()

    while True:
        try:
            net_ok = check_internet()

            if net_ok:
                if is_online:
                    logger.debug("💚 外网正常且已认证，静默保活中...")
                else:
                    is_online = authenticate()
                time.sleep(KEEP_ALIVE_INTERVAL)
            else:
                if is_online:
                    logger.warning("⚠️ 外网断开，重置认证状态")
                    is_online = False
                logger.warning("🔄 正在尝试重新认证...")
                is_online = authenticate()
                time.sleep(RETRY_INTERVAL)

        except KeyboardInterrupt:
            logger.info("🛑 用户手动中断，脚本已安全退出。")
            sys.exit(0)
        except Exception as e:
            logger.error(f"💥 守护进程发生未知异常: {e}")
            time.sleep(RETRY_INTERVAL)


if __name__ == "__main__":
    keep_alive_loop()
