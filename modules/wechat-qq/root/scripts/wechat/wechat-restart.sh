#!/bin/bash
set -e

pkill -9 -f /usr/bin/wechat 2>/dev/null
nohup /scripts/wechat/wechat-start.sh >/dev/null 2>&1 &
