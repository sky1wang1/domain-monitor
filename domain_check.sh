#!/bin/bash
BASE_DIR="/root/domain-monitor"
DOMAIN_FILE="$BASE_DIR/domains.txt"
STATE_DIR="$BASE_DIR/state"
TOKEN="${FEISHU_TOKEN}"

send_msg(){
    /bin/bash "$BASE_DIR/feishumsg.sh" "$1" "$TOKEN"
}

while read -r domain
do
    [ -z "$domain" ] && continue

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

    if [ -z "$expire" ] || [ "$expire" = "null" ]; then
        echo "$domain 查询失败"
        continue
    fi

    expire_ts=$(date -d "$expire" +%s)
    now_ts=$(date +%s)

    remain_days=$(( (expire_ts-now_ts)/86400 ))

    echo "$domain 剩余 $remain_days 天"

    expire_show=$(TZ=Asia/Shanghai date -d "$expire" '+%Y-%m-%d %H:%M:%S')
    check_time=$(TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S')

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

    [ -z "$level" ] && continue

    state_file="$STATE_DIR/$domain.json"

    last_level=$(jq -r '.level // empty' "$state_file" 2>/dev/null)

    if [ "$last_level" = "$level" ]; then
        continue
    fi

    msg="
⚠️ 域名到期提醒

域名:
$domain

状态:
正常

到期时间:
$expire_show (Asia/Shanghai)

剩余:
$remain_days 天

提醒阶段:
${level}天周期提醒

检查时间:
$check_time
"

    send_msg "$msg"

    cat > "$state_file" <<EOF
{
  "domain": "$domain",
  "expire": "$expire",
  "last_notice": "$check_time",
  "level": "$level",
  "remain_days": "$remain_days"
}
EOF

done < "$DOMAIN_FILE"
