#!/usr/bin/env bash
# Creates a GitLab project under a group via REST API v4.
# Usage: see README.md in this directory.

set -euo pipefail

API_BASE="${GITLAB_API_BASE:-https://ako.le1e.com/gitlab/api/v4}"
TOKEN="${GITLAB_TOKEN:-}"
if [[ -z "$TOKEN" ]]; then
  echo "Set GITLAB_TOKEN (Personal/Project Access Token with api scope)." >&2
  exit 1
fi

DEFAULT_GROUP="MaxGp"
if [[ $# -eq 1 ]]; then
  GROUP="$DEFAULT_GROUP"
  PROJECT="$1"
elif [[ $# -eq 2 ]]; then
  GROUP="$1"
  PROJECT="$2"
else
  echo "Usage: $0 <project-name>" >&2
  echo "   or: $0 <group-path> <project-name>  (default group: $DEFAULT_GROUP)" >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "Requires: curl, jq (e.g. sudo apt-get install -y curl jq)" >&2
  exit 1
fi

enc_group=$(printf '%s' "$GROUP" | jq -sRr @uri)
group_json=$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$API_BASE/groups/$enc_group")
if echo "$group_json" | jq -e '.id' >/dev/null 2>&1; then
  namespace_id=$(echo "$group_json" | jq -r '.id')
else
  echo "Cannot resolve group '$GROUP':" >&2
  echo "$group_json" >&2
  exit 1
fi

slug=$(printf '%s' "$PROJECT" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+|-+$//g; s/-+/-/g')

create_body=$(jq -n \
  --arg name "$PROJECT" \
  --arg path "$slug" \
  --argjson ns "$namespace_id" \
  '{name: $name, path: $path, namespace_id: $ns}')

resp=$(curl -sS -w "\n%{http_code}" -H "PRIVATE-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$API_BASE/projects" \
  -d "$create_body")
http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

if [[ "$http_code" != "201" ]]; then
  echo "Create failed HTTP $http_code" >&2
  echo "$body" >&2
  exit 1
fi

echo "Created: $(echo "$body" | jq -r '.path_with_namespace') (id=$(echo "$body" | jq -r '.id'))"
echo "SSH:   $(echo "$body" | jq -r '.ssh_url_to_repo // empty')"
echo "HTTPS: $(echo "$body" | jq -r '.http_url_to_repo // empty')"
