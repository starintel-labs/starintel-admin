# starintel-admin

Unified StarIntel operator and administration application.

Deployment is owned by `starintel-labs/starintel-infra`.
Relevant public hostname: `admin.starintel.actor`.

## Portable CLI

The repository now owns a small Bash control-plane client. It talks to the
authenticated StarIntel HTTP API with `curl` + `jq`, emits JSON, and is packaged
as a Nix flake.

```sh
nix run github:starintel-labs/starintel-admin -- user list
nix run . -- plan set analyst tenant-pro
nix run . -- dataset planned breach-corpus tenant-pro
nix run . -- documents tenant tenant-pro '*:*' 250
nix run . -- stats user alice
nix run . -- stats group discord-server-123 tenant-pro
```

Plans deliberately use StarIntel tenant IDs. A planned user gets a
`tenant:<plan-id>` scope plus `dataset:*`; capability scopes are preserved.

### Secrets

No credential is stored in this repository. Runtime resolution is:

1. `STARINTEL_ADMIN_TOKEN`;
2. `STAR_SERVER_TOKEN` / `STAR_SERVER_API_KEY`;
3. `STARINTEL_ADMIN_TOKEN_FILE`;
4. existing single-line files under `~/.config/starintelinfra/` when present.

Bearer secrets are supplied to curl through a mode-0600 temporary config instead
of an Authorization argument visible in the process list.

Image generation uses `OPENROUTER_API_KEY` or
`STARINTEL_ADMIN_IMAGE_KEY_FILE`. If neither is set, the client checks
`~/.config/starintelinfra/openrouter-api-key` and `openrouter.key` if they
exist. The default model matches the dotfiles image stack:
`openai/gpt-image-2`.

## Dataset policy

`dataset public|private|planned` writes durable operator desired state in
`$XDG_CONFIG_HOME/starintel-admin/datasets.json` and immediately replaces the
server's live policy through `PUT /admin/dataset-policy`.

- **private** is the sane default: absent from public and planned runtime sets.
- **public** enters the explicit public allowlist.
- **planned** binds a dataset to one tenant/plan ID.

The server policy is intentionally runtime-only. The local registry is the
durable authority and `dataset apply` replays it after server restart;
`dataset status` shows the current live generation/state. A failed live apply
does not discard desired state, so operators can repair connectivity and replay.
`dataset tenant-map` remains available for infra/environment compatibility.

## Data-size semantics

`stats user USER` resolves the authenticated account's `tenant:<id>` plan
scopes, queries each tenant, deduplicates documents, and reports the **logical
JSON bytes accessible to that account**. StarIntel does not currently persist a
creator-principal on intelligence documents, so this is deliberately *not*
reported as user-owned storage.

`stats group TENANT_OR_PLAN` measures the corresponding tenant/plan user group.
`stats tenant` exposes the same tenant primitive directly. All three return
document count, logical JSON bytes, and MiB; none are claimed to be physical
CouchDB/S3 disk usage.

## User revoke / plan mutation

The CLI targets the user lifecycle extension `PUT /auth/users/:username` for
scope/status updates. `user revoke` disables the user and revokes all active or
disabled credentials owned by that username.

`plan set` and `plan revoke` also revoke credentials owned by that user after
the persisted scope update. New sessions/API keys must therefore be minted from
the new tenant/plan scopes; stale credentials cannot retain removed plan access.

Existing credential revoke uses the current stable server endpoint.
