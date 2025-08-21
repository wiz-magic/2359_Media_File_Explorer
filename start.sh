#!/bin/bash
echo "Media File Explorer 시작 중..."
sleep 2
open http://localhost:3000 2>/dev/null || xdg-open http://localhost:3000 2>/dev/null
node local-server.cjs

