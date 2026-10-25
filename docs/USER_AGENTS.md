# User-Agent 参考与替换方法

[返回项目说明](../README.md)

这里的“请求头样例”主要指 `User-Agent`，不是某台设备完整的认证抓包。请尽量替换为自己设备上、实际发起校园网认证的浏览器所发送的值，先在电脑上的 Python 脚本中测试，再同步到路由器 Shell 脚本。

**以下样例未逐台设备验证校园网认证结果。** 小米 6、10 的条目是带机型字段的构造样例；小米 17、OPPO A5 使用通用 Android 格式；iPhone 样例来自 WebKit 公布的浏览器格式。示例浏览器版本用于展示格式，不表示当前最新版本。

## 先了解 UA 中的设备信息

- 现代 Chromium 浏览器会精简 UA。Android 可能统一显示 `Android 10; K`，macOS 可能显示固定的 `Intel Mac OS X 10_15_7`，这些字段不一定是设备真实系统信息。[Chromium 官方说明](https://www.chromium.org/updates/ua-reduction/)
- Windows 10 和 Windows 11 的 Chrome / Edge 都可能包含 `Windows NT 10.0`，不能通过把它改成 `Windows NT 11.0` 来获得真实的 Windows 11 UA。[Microsoft 官方说明](https://learn.microsoft.com/en-us/microsoft-edge/web-platform/how-to-detect-win11)
- Safari 的常规 iPhone UA 不包含“iPhone 17”这样的具体机型；WebKit 公布的 Safari 26.0 示例仍包含 `iPhone OS 18_6`。[WebKit 官方说明](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/)

因此，不要只把 `MI 8` 改成另一款设备名称，并将它当成该设备的真实请求头。UA 只是一个请求字段，修改 UA 不等于修改设备 MAC，也不保证服务器按预期识别终端类型。

## 手机端参考

### 小米 6：带机型字段的构造样例

以下 Android / Chrome 版本仅用于演示旧式 UA 的组成，没有本次实机抓包验证：

```text
Mozilla/5.0 (Linux; Android 9; MI 6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36
```

### 小米 10：带机型字段的构造样例

以下也是构造样例，不代表所有小米 10 系统或浏览器版本：

```text
Mozilla/5.0 (Linux; Android 10; Mi 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Mobile Safari/537.36
```

### 小米 17、OPPO A5：通用 Android Chrome 样例

没有这两款设备的实机抓包，下面提供符合 Chromium 精简格式的通用样例。它不携带具体机型，也不声称是这两款设备原生浏览器的实际 UA。若设备浏览器发送了机型信息，应优先复制实际认证请求中的完整值。

```text
Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36
```

### iPhone 17 等 iPhone：Safari 26.0 格式参考

下列字符串为 [WebKit 官方公布的 Safari 26.0 示例](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/)，供 iPhone 17 等设备的格式选择参考，不是对某台 iPhone 17 的抓包记录。不要在其中手动加入 `iPhone 17`。

```text
Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1
```

### 小米 8：原脚本自带样例

项目原有的手机端脚本使用下面的字符串。本条仅记录原有配置，同样应按自己的实际认证请求替换：

```text
Mozilla/5.0 (Linux; Android 10; zh-cn; MI 8 Build/QKQ1.190828.002) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/115.0.5790.168 Mobile Safari/537.36 XiaoMi/MiuiBrowser/17.5.40216
```

## 电脑端参考

### Windows 10 / Windows 11：Chrome 格式样例

两个系统可能使用相同的系统字段。以下为依照 Chromium 格式构造的样例：

```text
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36
```

### Windows 10 / Windows 11：Edge，原电脑端脚本样例

```text
Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/153.0.0.0 Safari/537.36 Edg/153.0.0.0
```

这是当前脚本自带的值，并非本次从电脑浏览器采集的记录。如要贴近自己的浏览器，应复制实际请求，不要将示例版本号视为当前版本。

### Mac：Chrome 格式样例

以下使用 Chromium 精简格式中的 macOS 字段；它不用于判断 Mac 的实际系统版本或 CPU 架构：

```text
Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36
```

### Linux 电脑：Chrome 格式样例

```text
Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36
```

## 在脚本中如何替换

### Python：电脑测试脚本

在 `src/pc/login.py` 中，替换 `PC_UA` 的整个字符串，保留变量名：

```python
PC_UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"
```

在 `src/mobile/login.py` 中，替换 `MOBILE_UA` 的整个字符串：

```python
MOBILE_UA = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36"
```

两份 Python 脚本都在电脑上运行。`mobile` 表示采用手机端请求头，不要求在手机上运行 Python。

### Shell：手机端请求头版本

在 `src/mobile/login.sh` 顶部替换 `MOBILE_UA`。当前 curl 和 wget 分支都引用这个变量，因此改一处即可：

```sh
MOBILE_UA="Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36"
```

### Shell：电脑端请求头版本

当前 `src/pc/login.sh` 没有统一的 UA 变量：curl 使用写在 `-A` 后面的完整字符串，wget 分支使用 `--header="User-Agent: Mozilla/5.0"`。替换时请同时修改两处，避免 curl 不可用时回退到另一种 UA。

如果希望今后只改一处，可自行在配置区加入：

```sh
PC_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"
```

然后将原 curl 命令的 UA 参数改为 `-A "$PC_UA"`，原 wget 命令的 UA 参数改为 `--header="User-Agent: $PC_UA"`。这两个参数属于各自原有的请求命令，保留原来的换行续接符 `\`，不要作为独立命令执行。

### Referer 等其他字段

`User-Agent` 用来描述浏览器，`Referer` 则与实际认证页面来源有关。不要因为更换手机型号就随意更改认证服务器地址；如果真实认证请求中的 Referer 不同，应按抓包结果同步调整。当前电脑端、手机端脚本本身使用了不同的 Referer。

## 获取自己的真实认证请求

1. 在自己的设备上打开校园网认证页面。电脑浏览器可按 `F12` 打开开发者工具，进入“网络 / Network”，开启“保留日志 / Preserve log”。
2. 正常进行一次认证，查找发送到认证服务器的登录请求。当前脚本对应 `/eportal/` 下包含 `c=Portal`、`a=login` 的请求；实际页面也可能使用其他接口。
3. 在“请求标头 / Request Headers”中复制完整的 `User-Agent` 和 `Referer`，并核对认证接口、账号格式及其他请求参数。
4. 手机可使用设备支持的远程调试或抓包方式，查看自己设备发出的认证请求。浏览器控制台中的 `navigator.userAgent` 可辅助查看当前浏览器 UA，但最终以实际认证请求为准。
5. 将相关值写入电脑测试脚本，确认能正常认证和访问外网后，再更新路由器上的 Shell 配置。

如愿意向项目补充样例，请注明设备、系统、浏览器及版本，以及认证是否成功。分享前隐藏账号、密码等个人信息。

联通认证目前没有可验证的账号及请求记录，不能通过修改 UA 推断联通的账号前后缀，具体待后续抓包补充。
