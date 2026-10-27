# clash-rules

自托管的 Clash / mihomo 分流名单（rule-providers），从 [MetaCubeX/meta-rules-dat](https://github.com/MetaCubeX/meta-rules-dat) 拉取为 **YAML 文本**，替代原先直接引用上游 `.mrs` 二进制的写法。

目的是：名单变成纯文本、进 Git 版本管理，改一条规则不用重新生成二进制，`git diff` 就是分流变更的审阅视图。

## 目录结构

```
clash-rules/
├── rules/                    # behavior: domain / classical
│   ├── reject.yaml           # 广告拦截（上游 category-ads-all）
│   ├── private.yaml
│   ├── openai.yaml
│   ├── anthropic.yaml
│   ├── youtube.yaml
│   ├── netflix.yaml
│   ├── spotify.yaml
│   ├── telegram.yaml
│   ├── twitter.yaml
│   ├── google.yaml
│   ├── github.yaml
│   ├── microsoft.yaml
│   ├── apple.yaml
│   ├── gfw.yaml
│   ├── cn-domain.yaml
│   └── applications.yaml     # behavior: classical（进程名规则）
├── ipcidr/                   # behavior: ipcidr
│   ├── telegramip.yaml
│   └── cn-ip.yaml
├── rule-providers.local.yaml # 挂载方式 A：本地文件
├── rule-providers.remote.yaml# 挂载方式 B：指向自己的 GitHub 仓库
└── scripts/sync.sh           # 从上游重新拉取
```

## 名单清单

| provider | behavior | 条数 | 上游源 |
|---|---|---:|---|
| reject | domain | 904 | geosite/category-ads-all |
| private | domain | 132 | geosite/private |
| openai | domain | 24 | geosite/openai |
| anthropic | domain | 19 | geosite/anthropic |
| youtube | domain | 178 | geosite/youtube |
| netflix | domain | 24 | geosite/netflix |
| spotify | domain | 28 | geosite/spotify |
| telegram | domain | 21 | geosite/telegram |
| twitter | domain | 24 | geosite/twitter |
| google | domain | 1078 | geosite/google |
| github | domain | 65 | geosite/github |
| microsoft | domain | 753 | geosite/microsoft |
| apple | domain | 1791 | geosite/apple |
| gfw | domain | 4424 | geosite/gfw |
| cn-domain | domain | 110175 | geosite/cn |
| telegramip | ipcidr | 12 | geoip/telegram |
| cn-ip | ipcidr | 10011 | geoip/cn |
| applications | classical | 99 | Loyalsoldier/clash-rules |

## 挂载方式

### A. 本地文件（推荐先用）

把 `rule-providers.local.yaml` 里的 `__RULES_DIR__` 换成本仓库绝对路径，然后整段替换主配置里的 `rule-providers:`。

```yaml
    path: /Users/you/Documents/clash-rules/rules/apple.yaml
```

- 改完名单直接在 Clash Verge 里「重载配置」即生效，不用等 `interval`
- `type: file` 不需要 `interval`
- 本机路径写死在配置里，不适合多机共用

### B. 自己的 GitHub 仓库（多机同步）

1. 建一个 **public** 仓库（Clash Verge 无法为 raw 请求加鉴权头，private 拉不到）
2. 推到 `main` 分支
3. 把 `rule-providers.remote.yaml` 里的 `__RAW_BASE__` 换成
   `https://raw.githubusercontent.com/<用户名>/<仓库>/main`
4. 主配置里 `path:` 指向 Verge 的可写目录（如 `./ruleset/apple.yaml`），由内核缓存

## 更新名单

```bash
./scripts/sync.sh          # 拉取并覆盖
./scripts/sync.sh --check  # 只显示哪些名单有变动，不写文件
```

建议流程：`sync.sh` → `git diff` 看上游到底改了什么 → 确认后再 commit。这样上游哪天把某个域名移出名单、导致分流跑偏，你能在 diff 里看到，而不是被静默更新。

## 维护自己的分流

两种改法，按稳定性选：

**1. 只改某个名单**（比如让国区 Apple 直连）
直接编辑 `rules/apple.yaml` 加条目，或用 `rules/` 下另建一个自己的文件，在配置里多挂一个 provider：

```yaml
rule-providers:
  my-apple:
    type: file
    behavior: domain
    format: yaml
    path: __RULES_DIR__/rules/my-apple.yaml
```

**2. 只改规则顺序**（不改名单内容）
在 `rules:` 里用 `prepend-rules`（或把规则写在 `RULE-SET,apple,PROXY` 之前）：

```yaml
rules:
  # 国区 Apple 服务直连，必须排在 apple 之前
  - DOMAIN-SUFFIX,apple.com.cn,DIRECT
  - DOMAIN-SUFFIX,icloud.com.cn,DIRECT
  - DOMAIN-SUFFIX,push.apple.com,DIRECT
  - RULE-SET,apple,PROXY
```

> 注意：`rules/` 里的 `cn-domain.yaml`（11 万条）和 `gfw.yaml`（4400 条）不建议手改，改了就很难再跟上游合并。要加自己的规则请另建文件。

## 当前状态（2026-10-27 已切换）

主配置 `~/Library/Mobile Documents/com~apple~CloudDocs/Clash/config.yaml` 的 `rule-providers:` 已改为指向本仓库：

- 格式：`type: http` + `format: yaml`（原来是 `format: mrs` 二进制）
- URL：`https://raw.githubusercontent.com/cha0sal3r/clash-rules/main/...`
- 缓存：`./ruleset/<name>.yaml`，`interval: 86400`（24h 检查一次）

**备用 CDN**：若 `raw.githubusercontent.com` 被污染导致拉取失败，把各 `url` 换成
`https://cdn.jsdelivr.net/gh/cha0sal3r/clash-rules@main/<path>`。
两种地址都已实测可被内核直连拉取（18/18 全部加载）。

### 同时修掉的 Apple 分流

`rules:` 顶部新增 6 条直连规则（必须早于 `RULE-SET,apple,PROXY`）：

```yaml
  - DOMAIN-SUFFIX,apple.com.cn,DIRECT      # 国区域名
  - DOMAIN-SUFFIX,icloud.com.cn,DIRECT     # iCloud 中国网关
  - DOMAIN-SUFFIX,push.apple.com,DIRECT    # APNs，必须直连
  - DOMAIN-SUFFIX,apps.apple.com,DIRECT    # App Store 店面，含 amp-api.apps.apple.com
  - DOMAIN-SUFFIX,itunes.apple.com,DIRECT  # 含 iosapps / sf-api-token-service 子域
  - DOMAIN-SUFFIX,mzstatic.com,DIRECT      # 资源 CDN，国内有节点
```

起因：App Store 搜索报"无法连接"时，实测 Apple 全量流量（含 APNs 5223）都被 `RULE-SET,apple,PROXY` 送进了美国节点，而该组唯一的 Vmess 节点当时已宕机（延迟全 0）。

**回退**：删掉这 6 行即恢复"Apple 全部走代理"。如果你的 Apple ID 是非国区、需要固定走代理访问对应店面，也应删掉 `apps.apple.com` / `itunes.apple.com` 两行（保留 `push.apple.com` 直连）。

### 改完如何生效

1. 改本仓库 → `git commit` → `git push`
2. Clash Verge 里点「重载配置」（不会自动重载；重启应用也会应用）
3. 内核在 `interval` 到期后才会重新拉取远端名单，重载只让**规则顺序**和本地缓存立即生效

> 想改完立刻生效而不等 24h：Verge 的「配置 → 右键当前配置 → 更新」会强制重拉，或把 `interval` 临时调小。

## 注意

- 这些名单只决定「命中哪条规则」，出口还取决于主配置里 `RULE-SET,<name>,<策略组>` 的写法，两边要一起看。
- 编辑 `cn-domain.yaml` 这类大文件时注意编辑器不要重排缩进，mihomo 对 YAML 缩进敏感。
- 名单条目语法：`domain.com`（含子域）、`+.domain.com`（含子域，显式写法）、`*.domain.com`、`keyword:xxx`、`regexp:xxx`。
