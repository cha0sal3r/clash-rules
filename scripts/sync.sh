#!/usr/bin/env bash
# 从 MetaCubeX/meta-rules-dat 拉取 rule-provider 名单（YAML 文本版）。
# 用法: ./scripts/sync.sh [--check]
#   --check  只比对差异，不写文件（等价于 git diff 预览）
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GEOSITE="https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geosite"
GEOIP="https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/geoip"
APPS="https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt"

# provider 名 : 上游源名 : 目标路径
MAP=(
  "reject:category-ads-all:rules/reject.yaml"
  "private:private:rules/private.yaml"
  "openai:openai:rules/openai.yaml"
  "anthropic:anthropic:rules/anthropic.yaml"
  "youtube:youtube:rules/youtube.yaml"
  "netflix:netflix:rules/netflix.yaml"
  "spotify:spotify:rules/spotify.yaml"
  "telegram:telegram:rules/telegram.yaml"
  "twitter:twitter:rules/twitter.yaml"
  "google:google:rules/google.yaml"
  "github:github:rules/github.yaml"
  "microsoft:microsoft:rules/microsoft.yaml"
  "apple:apple:rules/apple.yaml"
  "gfw:gfw:rules/gfw.yaml"
  "cn-domain:cn:rules/cn-domain.yaml"
  "telegramip:telegram:ipcidr/telegramip.yaml"
  "cn-ip:cn:ipcidr/cn-ip.yaml"
)

check_only=0
[[ "${1:-}" == "--check" ]] && check_only=1

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

fail=0
for item in "${MAP[@]}"; do
  IFS=: read -r name src dest <<<"$item"
  case "$dest" in
    ipcidr/*) url="$GEOIP/$src.yaml" ;;
    *)        url="$GEOSITE/$src.yaml" ;;
  esac

  if ! curl -fsSL --retry 2 --max-time 60 "$url" -o "$tmp/$name"; then
    printf '%-12s FAILED  %s\n' "$name" "$url" >&2
    fail=1
    continue
  fi

  # 校验：必须是 payload 列表且非空
  count=$(grep -c '^\s*-\s' "$tmp/$name" || true)
  if [[ "$count" -eq 0 ]]; then
    printf '%-12s EMPTY   %s\n' "$name" "$url" >&2
    fail=1
    continue
  fi

  if [[ $check_only -eq 1 ]]; then
    if ! diff -q "$tmp/$name" "$ROOT/$dest" >/dev/null 2>&1; then
      printf '%-12s CHANGED (%s entries)\n' "$name" "$count"
    fi
  else
    cp "$tmp/$name" "$ROOT/$dest"
    printf '%-12s ok      %6s entries  -> %s\n' "$name" "$count" "$dest"
  fi
done

# applications 是 classical 行为，上游就是纯文本
if curl -fsSL --retry 2 --max-time 60 "$APPS" -o "$tmp/applications"; then
  if [[ $check_only -eq 1 ]]; then
    diff -q "$tmp/applications" "$ROOT/rules/applications.yaml" >/dev/null 2>&1 \
      || echo "applications CHANGED"
  else
    cp "$tmp/applications" "$ROOT/rules/applications.yaml"
    printf '%-12s ok      %6s entries  -> rules/applications.yaml\n' "applications" "$(grep -c . "$tmp/applications" || true)"
  fi
else
  echo "applications FAILED" >&2
  fail=1
fi

exit $fail
