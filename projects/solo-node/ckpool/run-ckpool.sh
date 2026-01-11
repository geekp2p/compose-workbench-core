#!/usr/bin/env bash
set -euo pipefail

rpc_host="${CKPOOL_RPC_HOST:-bitcoin-main}"
rpc_port="${CKPOOL_RPC_PORT:-8332}"
rpc_user="${CKPOOL_RPC_USER:-rpcuser_main}"
rpc_pass="${CKPOOL_RPC_PASSWORD:-rpcpass_main}"
payout_address="${CKPOOL_PAYOUT_ADDRESS:-}"

if [ -z "${payout_address}" ]; then
  echo "[ckpool] Missing CKPOOL_PAYOUT_ADDRESS; set it via docker-compose or env." >&2
  exit 1
fi

btc_sig="${CKPOOL_SIGNATURE:-/Solo via ckpool/}"
blockpoll="${CKPOOL_BLOCKPOLL:-100}"
nonce1="${CKPOOL_NONCE1_LENGTH:-4}"
nonce2="${CKPOOL_NONCE2_LENGTH:-8}"
update_interval="${CKPOOL_UPDATE_INTERVAL:-30}"
mindiff="${CKPOOL_MINDIFF:-1}"
startdiff="${CKPOOL_STARTDIFF:-32}"

cat <<JSON >/tmp/ckpool.conf
{
  "btcd": [
    {
      "url": "${rpc_host}:${rpc_port}",
      "auth": "${rpc_user}",
      "pass": "${rpc_pass}",
      "notify": true
    }
  ],
  "btcaddress": "${payout_address}",
  "btcsig": "${btc_sig}",
  "blockpoll": ${blockpoll},
  "nonce1length": ${nonce1},
  "nonce2length": ${nonce2},
  "update_interval": ${update_interval},
  "mindiff": ${mindiff},
  "startdiff": ${startdiff}
}
JSON

exec ckpool -c /tmp/ckpool.conf
# exec ckpool -E -c /tmp/ckpool.conf