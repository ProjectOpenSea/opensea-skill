#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: opensea-agent-relationships.sh <address_or_username>" >&2
  echo "Get the public agent ownership relationships for a profile" >&2
  echo "Only confirmed relationships are public; pending proposals are not" >&2
  echo "Example: opensea-agent-relationships.sh vitalik.eth" >&2
  exit 1
fi

identifier="$1"

"$(dirname "$0")/../opensea-get.sh" "/api/v2/accounts/${identifier}/agent-relationships"
