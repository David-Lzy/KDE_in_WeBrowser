#!/bin/bash
set -e

pkill -9 -f /usr/bin/qq 2>/dev/null
nohup /scripts/qq/qq-start.sh >/dev/null 2>&1 &
