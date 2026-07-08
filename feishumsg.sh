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
