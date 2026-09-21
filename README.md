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

`dataset public|private|planned` is an operator desired-state registry in
`$XDG_CONFIG_HOME/starintel-admin/datasets.json`.

- **private** is the sane default policy.
- **public** means intended unrestricted publication/access policy.
- **planned** binds a dataset to one tenant/plan ID.

`dataset tenant-map` emits the planned dataset mapping as
`dataset=tenant,...` for server/infra configuration. This registry does not
pretend the current server has a native dataset-policy endpoint; deployment can
consume it explicitly.

## Data-size semantics

`stats user`, `stats group`, and `stats tenant` report **logical JSON bytes**
for returned documents, plus document count and MiB. This is intentionally not
claimed to be CouchDB/S3 physical disk usage.

## User revoke / plan mutation

The CLI targets the user lifecycle extension `PUT /auth/users/:username` for
scope/status updates. `user revoke` disables the user and revokes all active or
disabled credentials owned by that username.

Existing credential revoke uses the current stable server endpoint.
