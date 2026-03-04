#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: opensea-get.sh <path> [query]" >&2
  echo "Example: opensea-get.sh /api/v2/collections/cool-cats-nft" >&2
  exit 1
fi

path="$1"
query="${2-}"
base="${OPENSEA_BASE_URL:-https://api.opensea.io}"
key="${OPENSEA_API_KEY:-}"

if [ -z "$key" ]; then
  echo "OPENSEA_API_KEY is required" >&2
  exit 1
fi

url="$base$path"
if [ -n "$query" ]; then
  url="$url?$query"
fi

max_retries=3
base_delay=2
tmp_body="$(mktemp)"
trap 'rm -f "$tmp_body"' EXIT

for (( attempt=1; attempt<=max_retries; attempt++ )); do
  http_code="$(curl -sS -w '%{http_code}' -o "$tmp_body" \
    -H "x-api-key: $key" -H "User-Agent: opensea-skill/1.0" "$url")"

  if [ "$http_code" != "429" ]; then
    cat "$tmp_body"
    exit 0
  fi

  if [ "$attempt" -lt "$max_retries" ]; then
    delay=$(( base_delay * (2 ** (attempt - 1)) ))
    echo "opensea-get.sh: 429 rate limited, retrying in ${delay}s (attempt ${attempt}/${max_retries})..." >&2
    sleep "$delay"
  fi
done

echo "opensea-get.sh: 429 rate limited, all ${max_retries} attempts exhausted" >&2
cat "$tmp_body"
exit 1
