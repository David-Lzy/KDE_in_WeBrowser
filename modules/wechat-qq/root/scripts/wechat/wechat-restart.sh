#!/bin/bash
pkill -9 -f /usr/bin/wechat 2>/dev/null
nohup /usr/bin/wechat >/dev/null 2>&1 &