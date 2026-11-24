#!/usr/bin/env bash
# Rodar com `sam local start-api` ativo em outro terminal (Git Bash/WSL no Windows)
URL=http://127.0.0.1:3000/guias
H='Content-Type: application/json'
echo "== 3 chamadas normais =="
for i in 1 2 3; do
  curl -s -w "\n(tempo: %{time_total}s)\n" -X POST $URL -H "$H" \
    -d '{"requisicaoId":"R-002","hospital":"H-Caruaru"}'
done
echo "== erro de validacao (400) =="
curl -s -w "\n(http %{http_code})\n" -X POST $URL -H "$H" -d '{}'
echo "== timeout (demorar=true) =="
curl -s -w "\n(http %{http_code}, tempo: %{time_total}s)\n" -X POST $URL -H "$H" \
  -d '{"requisicaoId":"R-003","demorar":true}'
