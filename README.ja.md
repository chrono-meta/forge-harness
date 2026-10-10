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
  <a href="README.md">English</a> · <a href="README.ko.md">한국어</a> · <a href="README.zh.md">中文</a> · <b>日本語</b>
</p>

# forge-harness (FH)

**FH は [Claude Code](https://github.com/anthropics/claude-code) のためのメタハーネスです。プロジェクトに必要なルール・ゲート・記憶からなるハーネスとスキルを作るのを助け、出荷する前にそれらを検査します。**

*ハーネス（harness）* とは、ひとつのプロジェクトで AI エージェントを包む仕組みです。セッションのたびに同じ指示を繰り返さなくて済むよう、
エージェントが従うルール、誤った変更を止める検査、学んだことの記録を備えます。*メタ*ハーネスは、そうしたハーネスをプロジェクトごとに作り、検証するハーネスです。

> **エージェントに毎回説明していたルールを、プロジェクトに置く。**

<p align="center"><b>あなたのエージェントだけでなく、あなたも捕まえる品質ゲート。</b></p>

## 誰のためか、何が得られるか

実際のプロジェクトで Claude Code（または他のコーディングエージェント）を使っていて、同じ説明の繰り返しや、変更が誤りだったと気づくのが遅すぎることに疲れている人のためのものです。得られるものは三つです。

| 得られるもの | 実際には | 根拠 |
|---|---|---|
| **マージ前のゲート** | 変更が入る*前*に diff を判定し、その変更が何を失ったかを名指しします。判定は grep する文章ではなく、型を持つ値（`PASS · PENDING · BLOCKED · ESCALATE`）です。エージェントのコードだけでなく、自分で書いたコードにも働きます。 | 下のデモ GIF · 他人が書いたコードでの実行と穴を仕込んだテスト（サンプル数つき）: [根拠](#根拠とその限界) |
| **引き継がれる記憶** | `tracks/` に各セッションで学んだことが残り、2 回目のセッションは 1 回目が止まったところから始まります。 | 設計意図です。セッション終了時に `tracks/_meta/` のカードが更新され、次のセッションが起動時にそれを読みます（[`CLAUDE.md`](CLAUDE.md) §Session Wrap-up）。このページには計測された効果へのリンクはありません。2 回目のセッションから現れる効果でもあります。 |
| **検査を選んでくれる相手** | 「このプロジェクトを診断して」または「このプロジェクトを加速して」と言うと、直すもの・入れるものの優先順位つき一覧が返ります。項目ごとに承認するまで何も変更されません。 | [`CLAUDE.md`](CLAUDE.md) に記述あり（§Field-Harness Diagnostic）。どのくらいの頻度で当たるかのベンチマークはなし |

<p align="center">
  <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/gate-block.gif" alt="regression guard blocking a change that dropped a Done When section, then passing once it is restored" width="820">
</p>
<p align="center">
  <sub>ガードの実際の実行を録画したものです（作り物ではありません。再生成するスクリプトは下にリンク）。エージェントがスキル仕様ファイル（<code>SKILL.md</code>）を「整理」して <b>Done When（完了条件）</b> の節を削除しました。ガードは BLOCK し、欠けた節を名指しします。その節を戻すと PASS になり、ほかの整理はそのまま出荷されます。<br>再生成: <code>brew install vhs &amp;&amp; vhs docs/demo/gate-block.tape</code></sub>
</p>

## クイックスタート

入口をひとつ選んでください。インストール方法も、得られるものも異なります。

**入口 ① — ゲートだけ。クローンもプラグインも Claude Code セッションも不要。**

```bash
cd your-repo && npx --package @chrono-meta/fh-gate fh-gate     # 現在のリポジトリの git diff をレビュー
```

`git diff` から変更ファイルを見つけてレビューバックエンドに送り、判定（`FH_GATE_VERDICT: PASS | PENDING | BLOCKED | ESCALATE`）と終了コードを出力します。PASS はレビューが実際に走ったときだけ PASS と数えます。バックエンドが一度も応答しなかった場合、dry run、未知の終了コードは PASS ではなく、GitHub Actions のステップはデフォルトでこれらを失敗として扱います。Node ≥ 16 と、インストールしてログイン済みのバックエンド CLI がひとつ必要です。`claude`（デフォルト）または `codex`（`FH_BACKEND=codex`）です。CI、pre-commit フック、別のエージェントと併用できます。GitHub Actions のステップと Homebrew tap もあります — [ゲートを実行する](docs/REFERENCE.md#run-it-outside-claude-code--the-fh-gate-cli)を参照してください。

**入口 ② — ハーネス全体を Claude Code の中で。**

```bash
claude plugin marketplace add https://github.com/chrono-meta/forge-harness.git
claude plugin install -s user fh-meta@forge-harness
git clone https://github.com/chrono-meta/forge-harness.git ~/projects/forge-harness
cd ~/projects/forge-harness && claude          # その後に入力: hi   （または 안녕 · こんにちは · 你好）
```

1. **クローンしたフォルダを Claude Code で開きます**（`cd … && claude` の行）。
2. **挨拶します。** 新しくクローンした状態なら、FH はチェックアウトを読み、セッションファイルがないことを確認して、新規ユーザー向けの短いメニューを開きます: *最初のプロジェクトを作る · 既存のプロジェクトを接続する · ガイドを読む*。インストールウィザードがまだ実行されていなければ、それも知らせます。

   <img src="https://raw.githubusercontent.com/chrono-meta/forge-harness/main/docs/demo/door2-menu.gif" alt="typing hi in a fresh forge-harness clone; FH reads the checkout, opens the new-user menu, and warns that the install wizard has not run yet" width="760">

3. **同じセッションで成果をひとつ持ち帰りましょう。** **「プロジェクトを接続して」** と言うと（FH が `../` の git リポジトリを探して `tracks/{project}/` を作ります）、続けて **「このプロジェクトを加速して」**（優先順位つきで、承認を経る計画）または **「/context-doctor を実行して」**（トークン浪費のスキャン）と言ってください。完全なセットアップは **`/install-wizard`** を実行します。項目をひとつずつ承認し、断ったものは記録されます。

**要件。** 入口 ② は Claude Code CLI が必要です（`claude --version`）。入口 ① は Node と `claude` または `codex` CLI が必要で、Claude Code セッションは不要です。FH 自身のゲートのひとつ（クローン内のテストスイート）は、追加で Python + PyYAML（`python3 -m pip install --user pyyaml`）が必要で、なければ fail-closed で止まります。
**どちらの入口かわからなければ** ① から始めてください。コマンドひとつで、グローバルインストールも不要です。入口 ② はより大きなインストールで、`fh-gate` CLI も同梱されます（[`CHEATSHEET.md`](CHEATSHEET.md)）。① で学んだことは無駄になりません。

プラグインだけ（クローンなし）でも動きますが、部分的です。スキルとエージェントは得られますが、`CLAUDE.md` のガバナンスや `tracks/` の記憶は得られません。初めての方向けの韓国語の手順: [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md)。

## 一枚の図で見る仕組み

意図された流れです。どの段階がコードで強制され、どの段階が AI に従えと伝えたルールによるのかは、下の「できること・できないこと」の表と [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md) にあります。

```
   やりたいことを言う  ──►  FH が意図を読む  ──►  二つの形のどちらかに鍛える
   （ふつうの言葉で）                              ├─ AI が従うルール    （CLAUDE.md、スキル）
                                                   └─ AI のいらないコード （フック、ゲート、スクリプト）
                                                             │
        ハーネスへのあらゆる変更が通る道 ◄───────────────────┘
        ┌──────────────────────────────────────────────────────────┐
        │ 1. 設計の*前に*「何が成功か / 絶対にやらないこと」を書き出す
        │ 2. 互いに独立した複数の角度から試す（別のモデル系列、別リポジトリの視点）
        │ 3. 残ったものが堅くなるまで攻撃する — それから出荷
        └──────────────────────────────────────────────────────────┘
                                   │
   不可逆なステップ（公開 · 削除 · 履歴の書き換え）は止まって人に尋ねる
   検査が測れなかったものは「未計測」と報告する — 0 とは報告しない
   各セッションが学んだことは tracks/ に書かれる  ──►  次のセッションはそこから始まる
```

ハブ（このリポジトリ）が共有の `knowledge/` とプロジェクトごとの `tracks/` を持ち、接続した各プロジェクトがハブを指します。全体マップ（すべてのノードが実在のパス）: [`docs/map/FH_MAP.md`](docs/map/FH_MAP.md)（インタラクティブ版: [chrono-meta.github.io/forge-harness](https://chrono-meta.github.io/forge-harness/)）。

## 三つの信念

1. **品質がてこで、速度はその結果です。** 作業仮説です: 冷静な目の検査を一度くぐった仕事は、あとからの手戻りが少ない。このページでベンチマークしたものではありません。
2. **作者は最悪のレビュアーです。** AI と作り終えたあと、あなたはその成果物の擁護者になります。だから意味のある検査は、あなたの推論を見たことのないレビュアーによる検査です — [`docs/WHY.md`](docs/WHY.md)。
3. **不可逆な境界には機械を、判断の余地は残す。** 元に戻せないところで止め、測っていないものは測っていないと認めます — [`docs/ETHOS.md`](docs/ETHOS.md)。

## できること・できないこと

| できること | できないこと（リポジトリ自身が述べているもの） |
|---|---|
| マージ前に diff を判定し、何を失ったかを名指しする | **事後のレビューの代わりになること。** 人に届くものを小さくするだけで、不要にはしません。実際の画面と実際の状態で動かして初めて現れるものは、引き続き人の仕事です |
| git フックでコミットとプッシュを止める（ルール、スクリプト、削除、強制プッシュ） | **止まることの保証。** フックはクライアント側で、`--no-verify` で迂回できます。サーバー側の下限は「main は PR のみ」と必須の CI チェックです。pre-commit フックは FH 自体を開発するためのものです — 自分のリポジトリには入れず、そちらでは入口 ① を使ってください |
| プロジェクトの教訓を次のセッションに持ち越す | **どこでも同じように動くこと。** 挨拶であなたの言語に合わせるのは、機械的な下限のない文章のルールです。2026-08-21 のブラインドテストでは、挨拶のあるバリエーションでメニューが出ませんでした |
| 別のモデル系列（Codex、Gemini、ローカル）でレビューを回し、ひとつの系列が見落とすものを拾う | **Claude Code の外で完全に使えること。** 他のランタイムは方法論と `fh-gate`/`fh-run` は得られますが、自動運転は得られません（[`docs/codex-compat.md`](docs/codex-compat.md)） |
| 短い依頼からプロジェクト用のハーネスを作る | **完成したハーネスを注文どおりに出すこと。** それを担うインキュベーターは一度だけ出力し、その回も全フローを飛ばしています — 進む方向であって、出荷された機能ではありません |

## 根拠とその限界

- **実在する第三者の diff（2026-05-31）。** OpenCode の AI が書いた `permission/arity.ts`（163 行、CI は緑）に `fh-gate` を実行しました。CI が見逃した A 等級の指摘が 2 件あり、判定は BLOCKED でした。
- **穴を仕込んだテスト、モデル固定（2026-07-14）。** 他の二つのモデルが書いた fail-open の穴が八つ。通常のレビュー 5/8（そのうち 2 件は別のバグを指していた）· + FH の degrade-direction レンズ 6/8 · + 二つ目のモデル系列 8/8、誤検知 0。**単一の試行、小さなサンプルです。** 要点は、単一モデルの 2 回の実行が*同じ*二つの穴を見落としたことです。方法は [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md)、ほかの実行は [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) にあります。
- **成熟度は主張ではなく等級です。** 下に名前を挙げた五つのアイデンティティは、[`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) で日付つきの等級を持ちます。どれかに頼る前に、その等級を読んでください。
- このページの数（**スキル 46 · エージェント 14**）は、`plugins/`（`fh-meta`、`fh-commons`、`fh-qp`、`fh-preprep`）配下のスキルフォルダとエージェントファイルを 2026-10-10 に数えたものです。フレーズ集: [`CHEATSHEET.md` §12](CHEATSHEET.md#12-skills--agents--what-each-does-and-what-to-say)。

## 使い始めると出会う言葉

始めるのに必要ではありません。FH がどう作られているかを名づけたもので、挨拶やゲートがひとつを使ったときに引いてください。ここでの定義は一行です。正典は [`fh_three_layer_canon.md`](knowledge/shared/harness-core/fh_three_layer_canon.md) です。

| 用語 | 一行 | さらに読む |
|---|---|---|
| **3段工程** | FH の仕事が踏む順序: まず成功を定義 → 並列に、相関を切って試す → 6 つの軸で焼き切る。速度は最後に出てきます。 | [`ETHOS.md`](docs/ETHOS.md#the-forge) |
| **4大エンジン** | 出力の源になる核: `judgment-circuit` · `ship-gate` · `context-continuity` · `external-grounding`。 | 上の正典 |
| **5つのアイデンティティ** | スキルが集まってできる形: ハーネスクラスター · プロジェクトインキュベーター · ガバナンスゲート · フロンティア吸収 · 増幅器。アイデンティティごとに等級が付きます。 | [`docs/IDENTITIES.md`](docs/IDENTITIES.md) · [`ship_readiness_gate.md`](knowledge/shared/harness-core/ship_readiness_gate.md) |
| **6軸検証** | レビュアーが*何を受け取ったか*で分かれる六つのレビュー方法: 別のモデル系列 · 対象自身の正典 · 隔離環境でのグラウンディング（根拠付け） · 第三者のリポジトリ · 初めての実使用 · 戻して観察。六つ全部を回すのではなく、選びます。 | 上の正典 |
| **脱相関（decorrelation）** | 二つの検査が*違う形で*失敗するようにして、一方が見落とすものを、もう一方が捉えられるようにすること。 | [`docs/REFERENCE.md`](docs/REFERENCE.md) |

そのほかの用語: [`GLOSSARY.md`](knowledge/shared/GLOSSARY.md)。

## 次に読むもの

| 知りたいこと | 行き先 |
|---|---|
| 最初のセッションを手順どおりに（韓国語） | [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) |
| コマンドとトリガーフレーズ | [`CHEATSHEET.md`](CHEATSHEET.md) |
| 以前の README の全文（エンジン、モデル設定、`fh-gate` フラグ、スキル一覧、論文） | [`docs/REFERENCE.md`](docs/REFERENCE.md) |
| 利用例とモデルティアごとの期待値 | [`docs/USE_CASES.md`](docs/USE_CASES.md) · [`docs/model_tier_expectations.md`](docs/model_tier_expectations.md) |
| なぜ存在するか / 何を信じるか / 根拠 | [`docs/WHY.md`](docs/WHY.md) · [`docs/ETHOS.md`](docs/ETHOS.md) · [`docs/OUTPUT_EVIDENCE.md`](docs/OUTPUT_EVIDENCE.md) |
| 貢献する | [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) |
| AI の運用ルール / ランタイムの入口 | [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) |

> **この文書は人のためのものです。** 役に立ったなら、スターをひとつもらえると、ほかの人が見つけやすくなります。
