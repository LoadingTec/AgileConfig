#!/usr/bin/env bash
# Creates a GitLab user (admin API) and adds them to a project with a role.
# Requires: GITLAB_TOKEN (admin + api); optional GITLAB_NEW_USER_PASSWORD
# Usage: see README.md

set -euo pipefail

API_BASE="${GITLAB_API_BASE:-https://ako.le1e.com/gitlab/api/v4}"
TOKEN="${GITLAB_TOKEN:-}"
if [[ -z "$TOKEN" ]]; then
  echo "Set GITLAB_TOKEN." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "Requires: curl, jq" >&2
  exit 1
fi

usage() {
  echo "Usage: $0 <email> <username> <display_name> <project_path> [group_path] [access]" >&2
  echo "  If <project_path> contains '/', it is the full path_with_namespace (e.g. MyGroup/dksys); [group_path] is ignored." >&2
  echo "  access: guest | reporter | developer | maintainer  (default: developer)" >&2
  echo "  group_path default: MaxGp (only when project_path has no '/')" >&2
  echo "  optional: GITLAB_NEW_USER_PASSWORD for initial password (avoid passing on argv)" >&2
  exit 1
}

[[ $# -lt 4 ]] || [[ $# -gt 6 ]] && usage

EMAIL="$1"
USERNAME="$2"
DISPLAY_NAME="$3"
PROJECT_RAW="$4"
GROUP="${5:-MaxGp}"
ACCESS="${6:-developer}"

# Full path: ... "ns/dksys" [access] — 5th arg is role, not group
if [[ "$PROJECT_RAW" == *"/"* ]]; then
  PATH_WITH_NS="${PROJECT_RAW#/}"
  PATH_WITH_NS="${PATH_WITH_NS%/}"
  if [[ $# -eq 5 ]]; then
    if [[ "$(printf '%s' "$GROUP" | tr '[:upper:]' '[:lower:]')" =~ ^(guest|reporter|developer|maintainer)$ ]]; then
      ACCESS="$(printf '%s' "$GROUP" | tr '[:upper:]' '[:lower:]')"
    fi
  elif [[ $# -eq 6 ]]; then
    echo "Too many arguments: when <project_path> contains '/', use at most 5 args (omit group): $0 ... \"group/repo\" [access]" >&2
    exit 1
  fi
else
  GROUP="${5:-MaxGp}"
  ACCESS="${6:-developer}"
fi

case "$(printf '%s' "$ACCESS" | tr '[:upper:]' '[:lower:]')" in
  guest) ACCESS_LEVEL=10 ;;
  reporter) ACCESS_LEVEL=20 ;;
  developer) ACCESS_LEVEL=30 ;;
  maintainer) ACCESS_LEVEL=40 ;;
  *) echo "Invalid access: $ACCESS" >&2; exit 1 ;;
esac

if [[ "$PROJECT_RAW" != *"/"* ]]; then
  slug=$(printf '%s' "$PROJECT_RAW" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+|-+$//g; s/-+/-/g')
  PATH_WITH_NS="${GROUP}/${slug}"
fi
enc_proj=$(printf '%s' "$PATH_WITH_NS" | jq -sRr @uri)

proj_json=$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$API_BASE/projects/$enc_proj")
if ! echo "$proj_json" | jq -e '.id' >/dev/null 2>&1; then
  echo "Project not found or no access: $PATH_WITH_NS" >&2
  echo "  Use full path_with_namespace if not under MaxGp, e.g. ./$0 ... 'MyGroup/dksys'" >&2
  echo "  404 often means wrong path or token cannot read the project." >&2
  echo "$proj_json" >&2
  exit 1
fi
PROJECT_ID=$(echo "$proj_json" | jq -r '.id')

PW="${GITLAB_NEW_USER_PASSWORD:-}"
if [[ -n "$PW" ]]; then
  user_body=$(jq -n \
    --arg email "$EMAIL" \
    --arg username "$USERNAME" \
    --arg name "$DISPLAY_NAME" \
    --arg password "$PW" \
    '{email:$email, username:$username, name:$name, password:$password, reset_password:false, skip_confirmation:true, force_random_password:false}')
else
  user_body=$(jq -n \
    --arg email "$EMAIL" \
    --arg username "$USERNAME" \
    --arg name "$DISPLAY_NAME" \
    '{email:$email, username:$username, name:$name, skip_confirmation:true, force_random_password:true, reset_password:false}')
fi

resp=$(curl -sS -w "\n%{http_code}" -H "PRIVATE-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$API_BASE/users" \
  -d "$user_body")
http_code=$(echo "$resp" | tail -n1)
body=$(echo "$resp" | sed '$d')

USER_ID=""
if [[ "$http_code" == "201" ]]; then
  USER_ID=$(echo "$body" | jq -r '.id')
  echo "Created user: $USERNAME (id=$USER_ID)"
  if [[ -z "$PW" ]]; then
    echo "Note: force_random_password; set password in Admin UI or use GITLAB_NEW_USER_PASSWORD for new users." >&2
  fi
else
  enc_u=$(printf '%s' "$USERNAME" | jq -sRr @uri)
  found=$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$API_BASE/users?username=$enc_u")
  if echo "$found" | jq -e 'length > 0' >/dev/null 2>&1; then
    USER_ID=$(echo "$found" | jq -r '.[0].id')
    echo "User already exists: $USERNAME (id=$USER_ID); skipping create."
  else
    echo "Create user failed HTTP $http_code" >&2
    echo "$body" >&2
    exit 1
  fi
fi

mem_body=$(jq -n --argjson uid "$USER_ID" --argjson al "$ACCESS_LEVEL" '{user_id:$uid, access_level:$al}')
mresp=$(curl -sS -w "\n%{http_code}" -H "PRIVATE-TOKEN: $TOKEN" \
  -H "Content-Type: application/json" \
  -X POST "$API_BASE/projects/$PROJECT_ID/members" \
  -d "$mem_body")
mcode=$(echo "$mresp" | tail -n1)
mbody=$(echo "$mresp" | sed '$d')

if [[ "$mcode" != "201" ]]; then
  echo "Add member failed HTTP $mcode" >&2
  echo "$mbody" >&2
  exit 1
fi

echo "Granted on $PATH_WITH_NS : $ACCESS (member id=$(echo "$mbody" | jq -r '.id'))"
