# domain-monitor
域名到期监控告警（Shell + RDAP + 飞书）

# 域名到期监控告警（Shell + RDAP + 飞书）

## 功能

- 支持多个域名监控
- 支持 `.kg` 等特殊后缀域名
- 使用 RDAP 查询域名注册到期时间
- 亚洲时间（Asia/Tokyo）每天 12:00 检查
- 到期前分级提醒：
  - 90 天
  - 60 天
  - 30 天
  - 7 天
  - 3 天
- 飞书机器人告警
- 状态记录避免重复提醒

---

# 目录结构

```text
/root/domain-monitor/

├── domains.txt          # 域名列表
├── domain_check.sh      # 域名检查脚本
├── feishumsg.sh         # 飞书通知脚本
└── state/               # 提醒状态记录
```

创建目录：

```bash
mkdir -p /root/domain-monitor/state
```

---

# 1. 域名列表

文件：

```bash
/root/domain-monitor/domains.txt
```

示例：

```text
example-random.edu.kg
example.com
test-domain.net
```

每行一个域名。

---

# 2. 飞书通知脚本

文件：

```bash
/root/domain-monitor/feishumsg.sh
```

内容：

```bash
#!/bin/bash

MSG="$1"
TOKEN="$2"

if [ -z "$MSG" ] || [ -z "$TOKEN" ]; then
    echo "Usage: $0 <message> <token>"
    exit 1
fi


JSON=$(jq -n \
  --arg text "$MSG" \
  '{
    msg_type: "text",
    content: {
      text: $text
    }
  }'
)


curl -s \
  -X POST \
  -H "Content-Type: application/json" \
  -d "$JSON" \
  "https://open.feishu.cn/open-apis/bot/v2/hook/${TOKEN}"
```

授权：

```bash
chmod +x /root/domain-monitor/feishumsg.sh
```

---

# 3. 域名检测脚本

文件：

```bash
/root/domain-monitor/domain_check.sh
```

内容：

```bash
#!/bin/bash


BASE_DIR="/root/domain-monitor"

DOMAIN_FILE="$BASE_DIR/domains.txt"

STATE_DIR="$BASE_DIR/state"


# 飞书机器人Token
TOKEN="${FEISHU_TOKEN}"



send_msg(){

    /bin/bash \
    $BASE_DIR/feishumsg.sh \
    "$1" \
    "$TOKEN"

}



while read domain
do

    [ -z "$domain" ] && continue



    # 根据域名后缀选择RDAP

    case "$domain" in

    *.kg)

        API="http://rdap.cctld.kg/domain/$domain"

        ;;

    *)

        API="https://rdap.org/domain/$domain"

        ;;

    esac



    expire=$(curl -s "$API" \
    | jq -r '
    .events[]
    | select(.eventAction=="Record expires")
    | .eventDate' 2>/dev/null)



    if [ -z "$expire" ] || [ "$expire" = "null" ]

    then

        echo "$domain 查询失败"

        continue

    fi



    expire_ts=$(date -d "$expire" +%s)

    now_ts=$(date +%s)



    remain_days=$((

    (expire_ts-now_ts)/86400

    ))



    echo "$domain 剩余 $remain_days 天"



    # 判断提醒等级

    level=""


    if [ "$remain_days" -le 3 ]; then

        level="3"


    elif [ "$remain_days" -le 7 ]; then

        level="7"


    elif [ "$remain_days" -le 30 ]; then

        level="30"


    elif [ "$remain_days" -le 60 ]; then

        level="60"


    elif [ "$remain_days" -le 90 ]; then

        level="90"


    fi



    # 未达到提醒时间

    [ -z "$level" ] && continue



    state_file="$STATE_DIR/$domain"



    last_level=$(cat "$state_file" 2>/dev/null)



    # 已经提醒过

    if [ "$last_level" = "$level" ]

    then

        continue

    fi



    msg="
⚠️ 域名到期提醒

域名:
$domain

到期时间:
$expire

剩余:
$remain_days 天

提醒等级:
剩余 ${level} 天

检测时间:
$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S')
"



    send_msg "$msg"



    # 保存提醒状态

    echo "$level" > "$state_file"



done < "$DOMAIN_FILE"
```

授权：

```bash
chmod +x /root/domain-monitor/domain_check.sh
```

---

# 4. 配置飞书 Token

不要直接写入脚本。

设置环境变量：

```bash
export FEISHU_TOKEN="your_feishu_bot_token"
```

测试：

```bash
echo $FEISHU_TOKEN
```

---

# 5. 手动测试

执行：

```bash
/root/domain-monitor/domain_check.sh
```

示例输出：

```text
example-random.edu.kg 剩余 64 天
```

提醒后生成状态文件：

```text
/root/domain-monitor/state/example-random.edu.kg
```

内容：

```text
90
```

表示已经发送过 90 天提醒。

---

# 6. 定时任务

编辑：

```bash
crontab -e
```

添加：

```cron
0 12 * * * TZ=Asia/Tokyo FEISHU_TOKEN=your_feishu_bot_token /root/domain-monitor/domain_check.sh >/dev/null 2>&1
```

说明：

- 每天 12:00 执行
- 使用亚洲时间
- 自动发送飞书提醒

---

# 7. 安装依赖

Debian / Ubuntu：

```bash
apt update

apt install -y curl jq
```

---

# 8. RDAP 查询测试

示例：

```bash
curl -s http://rdap.cctld.kg/domain/example-random.edu.kg
```

返回：

```json
{
  "eventAction": "Record expires",
  "eventDate": "2026-09-11T08:18:09Z"
}
```

表示：

```
UTC时间:
2026-09-11 08:18:09

亚洲东京时间:
2026-09-11 17:18:09
```

---

# 提醒策略

| 剩余时间 | 是否提醒 |
|---|---|
| >90天 | 不提醒 |
| ≤90天 | 提醒一次 |
| ≤60天 | 提醒一次 |
| ≤30天 | 提醒一次 |
| ≤7天 | 提醒一次 |
| ≤3天 | 提醒一次 |

---

# 后续扩展

可以继续增加：

```text
运维巡检系统

├── 域名到期检查
├── SSL证书检查
├── DNS解析检查
├── Docker服务检查
├── 磁盘空间检查
└── 飞书统一告警
```

适用于：

- 多 VPS 环境
- 小规模 SRE 运维
- 云服务器资产巡检