<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/banner.png" alt="forge-harness — Forge your projects, pass them through, faster. Quality is the lever — speed is the result." width="680">
</p>

<p align="center">
  <a href="https://github.com/walkinglabs/awesome-harness-engineering#coding-agent-harnesses"><img src="https://awesome.re/mentioned-badge.svg" alt="Mentioned in Awesome Harness Engineering"></a>
  <a href="https://github.com/VoltAgent/awesome-agent-skills#community-skills"><img src="https://img.shields.io/badge/listed_in-awesome--agent--skills-0ea5e9.svg" alt="Listed in awesome-agent-skills"></a>
  <a href="https://github.com/anthropics/claude-code"><img src="https://img.shields.io/badge/Claude_Code-compatible-a855f7.svg" alt="Claude Code compatible — official Claude Code repository"></a>
  <a href="https://chrono-meta.github.io/forge-harness/"><img src="https://img.shields.io/badge/whole_map-interactive-6366f1.svg" alt="FH whole map — interactive diagrams on GitHub Pages"></a>
  <a href="https://github.com/marketplace/actions/fh-gate-typed-ai-code-review-verdict"><img src="https://img.shields.io/badge/GitHub_Action-marketplace-2088FF.svg" alt="GitHub Actions Marketplace — fh-gate"></a>
  <a href="https://www.npmjs.com/package/@chrono-meta/fh-gate"><img src="https://img.shields.io/npm/v/@chrono-meta/fh-gate.svg?color=cb3837" alt="npm"></a>
  <a href="https://github.com/chrono-meta/homebrew-forge-harness"><img src="https://img.shields.io/badge/homebrew-tap-FBB040.svg" alt="Homebrew tap"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-22c55e.svg" alt="MIT License"></a>
</p>

<p align="center">
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <b>中文</b> · <a href="README.ja.md">日本語</a>
</p>

# forge-harness (FH)

**FH 是面向 [Claude Code](https://github.com/anthropics/claude-code) 的元框架（meta-harness）：它帮你搭建框架（harness）和技能——一个项目所需的规则、门禁与记忆——并在发布之前检查它们。**

*框架（harness）* 是你在某个项目里套在 AI agent 外面的那一层，让它不必每次会话都重新听一遍同样的指示：
它遵循的规则、拦住错误改动的检查，以及它学到了什么的记录。*元*框架则是那个一个项目接一个项目地搭建并验证这些框架的框架。

> **别再一遍遍向 agent 解释规则——把它们放进项目里。**

<p align="center"><b>不仅能发现 agent 的问题，也能发现你的问题的质量门禁。</b></p>

## 适合谁，你能得到什么

适合在真实项目里使用 Claude Code（或其他编码 agent），厌倦了重复同样的话、或者发现改动有误时已经太晚的人。你会得到三样东西：

| 你得到 | 实际表现 | 证据 |
|---|---|---|
| **合并前的门禁** | 在改动落地*之前*判定 diff，判定会点名这次改动丢掉了什么。判定是有类型的值（`PASS · PENDING · BLOCKED · ESCALATE`），而不是需要你去 grep 的文字。对 agent 写的代码有效，对你自己写的代码同样有效。 | 下方演示 GIF · 一次对他人所写代码的运行与一次埋洞测试，附样本量：[证据](#证据以及它薄弱的地方) |
| **能延续的记忆** | `tracks/` 记录每次会话学到的东西，第 2 次会话从第 1 次停下的地方开始。 | 设计意图。会话结束时更新 `tracks/_meta/` 里的卡片，下次会话启动时读取它（[`CLAUDE.md`](CLAUDE.md) §Session Wrap-up）。本页没有链接任何实测收益；而且它要从第 2 次会话起才看得出来。 |
| **替你挑检查的帮手** | 说“诊断这个项目”或“加速这个项目”，你会得到一份按优先级排序的待修复/待安装清单。逐项批准之前不会改动任何东西。 | 描述见 [`CLAUDE.md`](CLAUDE.md)（§Field-Harness Diagnostic）；没有关于它命中率的基准测试 |

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>录自守卫的一次真实运行（不是示意图；重新生成它的脚本链接在下面）：一个 agent “整理”了技能规格文件（<code>SKILL.md</code>），删掉了其中的 <b>Done When</b>（完成条件）一节。守卫 BLOCK，并点名缺失的那一节；把它放回去就返回 PASS，其余整理照常发布。<br>重新生成：<code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

## 快速开始

选一扇门。它们的安装方式不同，得到的东西也不同。

**门 ① —— 只要门禁。无需克隆，无需插件，无需 Claude Code 会话。**

```bash
cd your-repo && npx --package @chrono-meta/fh-gate fh-gate     # 审查当前仓库的 git diff
```

它通过 `git diff` 找到你改动的文件，发给审查后端，并输出判定（`FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE`）和退出码。只有审查真的跑过，PASS 才算数：后端始终没有应答、dry run、或者出现未知退出码，都不是 PASS，而 GitHub Actions 步骤默认会因此失败。需要 Node ≥ 16，以及安装并登录好的一个后端 CLI：`claude`（默认）或 `codex`（`FH_BACKEND=codex`）。可用于 CI、pre-commit 钩子，或放在另一个 agent 旁边。也有 GitHub Actions 步骤和 Homebrew tap——见[运行门禁](docs/REFERENCE.md#run-it-outside-claude-code--the-fh-gate-cli)。

**门 ② —— 在 Claude Code 里使用整套框架。**

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude          # 然后输入：hi   （或 안녕 · こんにちは · 你好）
```

1. **在 Claude Code 中打开克隆下来的文件夹**（即 `cd … && claude` 那一行）。
2. **打个招呼。** 在全新克隆里，FH 会读取检出内容，发现没有任何会话文件，于是打开一个面向新用户的简短菜单：*创建你的第一个项目 · 关联已有项目 · 阅读指南*。如果安装向导还没运行，它也会告诉你。

   <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="typing hi in a fresh forge-harness clone; FH reads the checkout, opens the new-user menu, and warns that the install wizard has not run yet" width="760">

3. **在同一次会话里拿到一次收获。** 说 **“关联一个项目”**（FH 会扫描 `../` 下的 git 仓库并创建 `tracks/{project}/`），然后说 **“加速这个项目”**（按优先级排序、需批准的计划）或 **“运行 /context-doctor”**（token 浪费扫描）。完整设置请运行 **`/install-wizard`**：每一项都逐个批准，拒绝的也会被记录。

**要求。** 门 ② 需要 Claude Code CLI（`claude --version`）。门 ① 需要 Node 和 `claude` 或 `codex` CLI，不需要 Claude Code 会话。FH 自己的某个门禁（克隆里的测试套件）另外需要 Python + PyYAML（`python3 -m pip install --user pyyaml`），缺少时会 fail-closed 拒绝通过。
**不确定选哪扇门？** 从 ① 开始：一条命令，不需要全局安装。门 ② 是更大的安装，同时也带有 `fh-gate` CLI（[`CHEATSHEET.md`](CHEATSHEET.md)）；你在 ① 里学到的东西一点也不会浪费。

只装插件（不克隆）也能用，但不完整：你会得到技能和 agent，得不到 `CLAUDE.md` 的治理规则或 `tracks/` 记忆。第一次使用的韩文逐步指引：[`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)。

## 一张图看懂它如何运作

这是设计上的流程。哪些步骤由代码强制、哪些由被告知要遵守的 AI 规则承担，见下方“能做与不能做”表和 [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md)。

```
   你说出想要什么  ──►  FH 读取意图  ──►  把它锻造成两种形态之一
   （日常语言）                            ├─ AI 遵循的规则    （CLAUDE.md、技能）
                                           └─ 不需要 AI 的代码  （钩子、门禁、脚本）
                                                     │
        对框架的每一次改动都要经过 ◄─────────────────┘
        ┌──────────────────────────────────────────────────────────┐
        │ 1. 设计之前，先写下“什么算成功 / 它绝不做什么”
        │ 2. 从几个相互独立的角度去试（另一个模型家族、另一个仓库的视角）
        │ 3. 一直攻击，直到剩下的是站得住的——然后再发布
        └──────────────────────────────────────────────────────────┘
                                   │
   不可逆的步骤（发布 · 删除 · 重写历史）会停下来问人
   检查没能测量的东西，报告为“未测量”——绝不报告成 0
   每次会话学到的东西写进 tracks/  ──►  下一次会话从那里开始
```

枢纽（本仓库）保存共享的 `knowledge/` 和每个项目各自的 `tracks/`；你关联的每个项目都指回它。完整地图，每个节点都是真实路径：[`docs/map/FH_MAP.md`](docs/map/FH_MAP.md)（交互版：[chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)）。

## 三个信念

1. **质量是杠杆，速度是结果。** 工作假设：经过一次冷眼审视的工作，之后需要的返工更少。本页没有对它做基准测试。
2. **作者是最差的审查者。** 和 AI 一起做完之后，你就成了它的辩护人，所以真正算数的检查，是由从未见过你的推理过程的审查者做的——[`docs/WHY.md`](docs/WHY.md)。
3. **在不可逆的边界上放机器；判断保持开放。** 在无法撤销的地方拦住，并承认你没有测量的东西——[`docs/ETHOS.md`](docs/ETHOS.md)。

## 能做与不能做

| 能做 | 不能做（仓库自己说明的） |
|---|---|
| 在合并前判定 diff，并点名它丢掉了什么 | **取代事后审查。** 它让到达人手里的东西变少，而不是变得不必要。只有在真实屏幕、真实状态下运行才会暴露的问题，仍然是人的工作 |
| 通过 git 钩子拦住提交和推送（规则、脚本、删除、强制推送） | **保证一定拦住。** 钩子在客户端，`--no-verify` 可以绕过；服务端的底线是“main 只能走 PR”加上必需的 CI 检查。它的 pre-commit 钩子是用来开发 FH 本身的——不要装进你自己的仓库，那里请用门 ① |
| 把一个项目的经验带入下一次会话 | **在所有地方表现一致。** 问候时匹配你的语言是一条没有机械底线的文字规则；2026-08-21 的一次盲测中，有一种问候变体没有出现菜单 |
| 让另一个模型家族（Codex、Gemini、本地）做审查，抓住单一家族漏掉的东西 | **在 Claude Code 之外完整可用。** 其他运行时得到方法论和 `fh-gate`/`fh-run`，得不到自动驾驶（[`docs/codex-compat.md`](docs/codex-compat.md)） |
| 根据一句简短的请求为项目搭建框架 | **按需产出成品框架。** 将来要做这件事的孵化器只产出过一次，而且那次跳过了完整流程——这是前进的方向，不是已发布的功能 |

## 证据，以及它薄弱的地方

- **一份真实的第三方 diff（2026-05-31）。** 对 OpenCode 中 AI 所写的 `permission/arity.ts`（163 行，CI 全绿）运行 `fh-gate`：判定 BLOCKED，依据是 CI 漏掉的两个 A 级发现。
- **埋洞测试，模型固定（2026-07-14）。** 另外两个模型写下的八个 fail-open 漏洞。普通审查 5/8（其中 2 个找错了 bug）· + FH 的 degrade-direction 视角 6/8 · + 第二个模型家族 8/8，误报 0。**单次抽样，样本很小。** 要点是两次单模型运行漏掉了*同样*的两个漏洞。方法见 [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)；更多运行见 [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md)。
- **成熟度是评级，不是宣称。** 下面列出的五重身份在 [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) 中带有注明日期的等级；依赖其中任何一个之前，先读它的等级。
- 本页的数字（**46 个技能 · 14 个 agent**）是 `plugins/`（`fh-meta`、`fh-commons`、`fh-qp`、`fh-preprep`）下的技能文件夹和 agent 文件，统计于 2026-10-10。用语手册：[`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say)。

## 用起来之后会遇到的词

开始时用不到这些。它们说明 FH 是怎么搭起来的，当问候或某个门禁用到其中一个时再来查。这里的定义只有一句话；正典是 [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md)。

| 术语 | 一句话 | 延伸阅读 |
|---|---|---|
| **三段工序** | FH 工作所遵循的顺序：先定义成功 → 并行、去相关地尝试 → 用六个轴烧一遍。速度是从末端出来的。 | [`ETHOS.md`](docs/ETHOS.md#the-forge) |
| **四大引擎** | 产生输出的核心机制：`judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`。 | 上述正典 |
| **五重身份** | 技能聚成的形态：框架集群 · 项目孵化器 · 治理门禁 · 前沿吸收 · 放大器。逐个身份评级。 | [`docs/IDENTITIES.md`](docs/IDENTITIES.md) · [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) |
| **六轴验证** | 六种审查方式，按审查者*拿到了什么*来划分：另一个模型家族 · 目标自己的正典 · 隔离式 grounding（依据建立） · 第三方仓库 · 首次真实使用 · 回退并观察。你按需挑选，不必六个都跑。 | 上述正典 |
| **去相关（decorrelation）** | 让两项检查以*不同的方式*失败，使一方看不见的东西被另一方看见。 | [`docs/REFERENCE.md`](docs/REFERENCE.md) |

其他术语：[`GLOSSARY.md`](knowledge/shared/GLOSSARY.md)。

## 接下来读什么

| 如果你想… | 去这里 |
|---|---|
| 一步一步走完第一次会话（韩文） | [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) |
| 命令与触发语 | [`CHEATSHEET.md`](CHEATSHEET.md) |
| 完整的旧 README（引擎、模型设置、`fh-gate` 参数、技能列表、论文） | [`docs/REFERENCE.md`](docs/REFERENCE.md) |
| 使用场景与各模型档位的预期 | [`docs/USE_CASES.md`](docs/USE_CASES.md) · [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md) |
| 为什么存在 / 相信什么 / 证据 | [`docs/WHY.md`](docs/WHY.md) · [`docs/ETHOS.md`](docs/ETHOS.md) · [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) |
| 参与贡献 | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| AI 运行规则 / 运行时入口 | [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) |

> **这份文档是写给人看的。** 如果它对你有用，点个 star 能帮助更多人找到它。
