#!/usr/bin/env bash
# VybzzZ — petit utilitaire Mux (local, tes cles restent en variables d'env).
#
#   export MUX_TOKEN_ID=xxxx
#   export MUX_TOKEN_SECRET=yyyy
#   ./scripts/mux.sh list                 # liste tes assets + playback ids
#   ./scripts/mux.sh create "https://.../video.mp4"   # cree un asset VOD
#
# Le PLAYBACK ID renvoye est PUBLIC : c'est lui qu'on colle dans
# APIs.muxDemoPlaybackId (lib/Global/api.dart) pour voir le replay dans l'app.
set -euo pipefail
: "${MUX_TOKEN_ID:?Definis MUX_TOKEN_ID}"
: "${MUX_TOKEN_SECRET:?Definis MUX_TOKEN_SECRET}"

AUTH="$MUX_TOKEN_ID:$MUX_TOKEN_SECRET"
API="https://api.mux.com/video/v1/assets"
cmd="${1:-list}"

case "$cmd" in
  list)
    curl -s -u "$AUTH" "$API?limit=25" | python3 -c '
import sys,json
data=json.load(sys.stdin).get("data",[])
if not data: print("(aucun asset)"); sys.exit()
for a in data:
    pid=(a.get("playback_ids") or [{}])[0].get("id","(none)")
    print(f"{a[\"status\"]:10}  playback_id={pid}  asset={a[\"id\"]}")
'
    ;;
  create)
    url="${2:?usage: ./scripts/mux.sh create <video-url>}"
    curl -s -u "$AUTH" -X POST "$API" \
      -H 'Content-Type: application/json' \
      -d "{\"input\":\"$url\",\"playback_policy\":[\"public\"]}" | python3 -c '
import sys,json
a=json.load(sys.stdin).get("data",{})
print("asset:", a.get("id"), "status:", a.get("status"))
pid=(a.get("playback_ids") or [{}])[0].get("id","(en cours...)")
print("playback_id:", pid)
print("HLS:", f"https://stream.mux.com/{pid}.m3u8" if pid and pid!="(en cours...)" else "(dispo quand status=ready)")
'
    ;;
  *)
    echo "usage: ./scripts/mux.sh [list | create <video-url>]"; exit 1;;
esac
