# spec-kit-skills

自动镜像 [github/spec-kit](https://github.com/github/spec-kit) 为 Codex 可安装的 Agent Skills，供 CC-Switch 统一分发和更新。

> 本仓库不是 Spec Kit 的 fork，也不重新实现 command → Skill 的转换。每次同步都会检出上游源码，并直接执行该版本官方 `specify` CLI；`skills/` 中的内容完全是官方 CLI 的生成结果。

## 给 CC-Switch 使用

在 CC-Switch 添加 GitHub 仓库时使用：

| 配置项 | 值 |
| --- | --- |
| Owner | `<GitHub Username>` |
| Name | `spec-kit-skills` |
| Branch | `main` |
| Subdirectory | `skills` |

CC-Switch 会将目录安装到全局 Agent Skills 路径，供 Codex 使用。`skills/` 是生成目录，请勿手工修改；下次同步会完整覆盖并删除上游已移除的内容。

## 同步策略

| 来源 | 频率 | 结果 |
| --- | --- | --- |
| 上游 `main` | 每天 | 用 `main` 重新生成 Skills；只有内容实际变化才提交。 |
| 上游最新稳定 Release | 每天 | 用 Release tag 重新生成，提交变化，在本仓库创建同名 Git tag 和 GitHub Release。 |

两个工作流共享并发锁，避免同时写入 `main`。Release 工作流也可通过 **Run workflow** 手动指定任意上游 tag；已经镜像的 Release 会被跳过。

生成版本记录在 [UPSTREAM.json](UPSTREAM.json)，其中不含时间戳，避免无意义更新。

## 本地维护

依赖：`git`、`uv`、`rsync` 和 Python 3。

```sh
make sync   # 默认从上游 main 生成
make check  # 校验生成内容与核心 Skills
```

`scripts/sync.sh` 支持：

- `SPEC_KIT_REPO`：上游仓库，默认 `https://github.com/github/spec-kit.git`
- `SPEC_KIT_REF`：branch、tag 或 commit SHA，默认 `main`

例如镜像一个已发布版本：

```sh
SPEC_KIT_REF=v1.0.1 make sync
```

同步脚本在临时目录运行官方源码的当前 CLI：

```sh
uv run --project <spec-kit-repo> specify init --here --force --non-interactive \
  --integration codex --integration-options="--skills" \
  --ignore-agent-tools --script sh
```

随后它以 `rsync --delete` 将临时项目的 `.agents/skills/` 镜像至 `skills/`，复制上游 `LICENSE` 至 `THIRD_PARTY_NOTICES/spec-kit-LICENSE`，并更新 `UPSTREAM.json`。校验会确认每个 Skill 的 `SKILL.md` 与 frontmatter，并确保核心 Skills 存在。

`make clean` 会删除生成目录和生成元数据；下一次 `make sync` 可完整恢复。

## 这不取代项目级 Spec Kit

本仓库只管理 Codex Spec Kit Skills，不能替代真实项目的 Spec Kit 基础设施：

```text
.specify/
├── memory/
├── scripts/
└── templates/
```

每个实际采用 Spec Kit 的项目仍应使用官方 `specify` CLI 初始化。
