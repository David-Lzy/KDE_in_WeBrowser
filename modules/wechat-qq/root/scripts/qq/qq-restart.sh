#!/bin/bash
pkill -9 -f /usr/bin/qq 2>/dev/null
nohup /usr/bin/qq --no-sandbox >/dev/null 2>&1 &