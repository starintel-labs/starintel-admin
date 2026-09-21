#!/usr/bin/env bash
set -Eeuo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/config"
export XDG_STATE_HOME="$TMP/state"
export STARINTEL_ADMIN_TOKEN=test-token
export STARINTEL_ADMIN_CURL="$TMP/fake-curl"
export STARINTEL_ADMIN_URL=http://star.test
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

cat >"$STARINTEL_ADMIN_CURL" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
url="${*: -1}"
method=GET
body=
while (($#)); do
  case "$1" in
    --request) method=$2; shift 2 ;;
    --data-binary) body=$2; shift 2 ;;
    *) shift ;;
  esac
done
case "$method $url" in
  "GET http://star.test/health")
    printf '{"status":"ok"}'
    ;;
  "GET http://star.test/auth/users")
    printf '[{"username":"alice","principal_type":"user","status":"active","scopes":["documents:read","search:read","tenant:old","dataset:*"]}]'
    ;;
  "GET http://star.test/auth/credentials")
    printf '[{"id":"key-a","owner":"alice","status":"active","scopes":["documents:read"]}]'
    ;;
  "PUT http://star.test/auth/users/alice")
    jq -cn --argjson body "$body" '{status:"ok",user:({username:"alice"} + $body)}'
    ;;
  "POST http://star.test/auth/credentials/key-a/revoke")
    printf '{"status":"ok","credential":{"id":"key-a","status":"revoked"}}'
    ;;
  "GET http://star.test/documents/messages/by-user?user=alice&limit=10000")
    printf '{"rows":[{"doc":{"_id":"m1","data":{"text":"hello"}}}]}'
    ;;
  "GET http://star.test/documents/socialmpost/by-user?user=alice&limit=10000")
    printf '{"rows":[{"doc":{"_id":"p1","data":{"text":"world"}}}]}'
    ;;
  *)
    printf 'unexpected request: %s %s\n' "$method" "$url" >&2
    exit 22
    ;;
esac
SH
chmod +x "$STARINTEL_ADMIN_CURL"

admin() {
  bash "$ROOT/bin/starintel-admin" "$@"
}

admin user list | jq -e '.[0].username=="alice"' >/dev/null
admin plan set alice pro | jq -e '.user.scopes | index("tenant:pro") != null' >/dev/null
admin plan revoke alice old | jq -e '.user.scopes | index("tenant:old") == null' >/dev/null
admin user revoke alice | jq -e '.user.status=="disabled"' >/dev/null
admin key revoke key-a | jq -e '.credential.status=="revoked"' >/dev/null

admin dataset private case-a | jq -e '.mode=="private"' >/dev/null
admin dataset public case-b | jq -e '.mode=="public"' >/dev/null
admin dataset planned case-c pro | jq -e '.mode=="planned" and .tenant_id=="pro"' >/dev/null
[[ "$(admin dataset tenant-map)" == "case-c=pro" ]]

stats=$(admin stats user alice)
jq -e '.document_count==2 and .logical_json_bytes > 0' <<<"$stats" >/dev/null

dashboard=$(admin dashboard json)
jq -e '.counts.users==1 and .counts.active_credentials==1' <<<"$dashboard" >/dev/null

printf 'admin-cli tests: OK\n'
