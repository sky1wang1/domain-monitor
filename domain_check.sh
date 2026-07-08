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
remain_days=$(( (expire_ts-now_ts)/86400 ))
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
