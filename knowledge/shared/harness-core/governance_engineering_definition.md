---
name: governance-engineering-definition
description: "Names the discipline this hub practices — governance engineering: moving an error rate toward 0.x% AND blocking at the surfaces where that number is not allowed to buy passage. Operator formulation 2026-09-09. Distinct from harness engineering (the artifact) — this is the objective."
type: reference
date: 2026-09-09
tags: [governance-engineering, naming, identity, error-budget, irreversible-surface]
---

# 거버넌스 엔지니어링 (Governance Engineering) — 정의

## 운영자 정식화 (2026-09-09, 축자)

> *"우리가 독창적으로 부를 엔지니어링은 '거버넌스 엔지니어링' 이라고 불러야할것같아.
> 0.x%의 오차율을 내기위한 목표로 움직이고 막고서는 엔지니어링"*

## 🟥 동사가 둘이다 — 그리고 둘째가 하중을 진다

정식화 안에 동사가 **둘** 있고, 이 이름의 값어치는 전부 그 둘이 같이 있다는 데 있다.

| | 무엇 | 없으면 |
|---|---|---|
| **움직인다** | 오차율을 0.x% 로 끌어내리는 것을 **목표로** 공정을 짠다 | 게이트만 남고 개선이 없다 — 「막기만 하는 관료」 |
| **막고 선다** | 그 수치가 **통과권을 사지는 못하는** 자리를 지킨다 | 「숫자를 충분히 낮추면 자동으로 통과」가 된다 |

🟥 **둘째 동사를 빼면 이 이름은 하루 만에 자기 교리와 모순된다.** 2026-09-08 에 상주화한
§Irreversibility Gates 의 문단(PR #687)이 정확히 그것을 금지한다 — *"do not promote a verdict engine
to an irreversible surface by improving its number."* 그 문단의 defeater 도 축자로 이렇게 적혀 있다:
「누군가 이 문단을 근거로 오류율 문턱을 만들면 이 문단이 실패한 것」.

⇒ **정의 문장은 한 줄로 이렇게 고정한다**:
> **수치를 목표로 움직이되, 그 수치가 게이트를 열지는 않는다.**
> 무엇이 허용되는가는 **표면 등급**이 정하지 숫자가 정하지 않는다.

## 첫 실증 내용 (이 이름이 비어 있지 않다는 근거)

🟥 **이 절의 초판이 인용한 5팔 표(2.7 %–13.6 %)를 2026-09-17 에 철회한다 — «낡아서»가 아니라
«그 수를 만든 자가 결함으로 판정되고 교체됐기» 때문이다.** 지우지 않고 아래에 남긴다(무엇이
인용됐었는지가 기록이다):

```
철회됨 — B-1 산문 채점 (2026-09-08)
O   octo 4자          2.7%
F_xf cross-family     5.3%
F   FH 기본           9.6%
N   맨몸              9.7%
F_slim 리뷰프로파일   13.6%
```

**왜 철회인가**: B-1 은 산문 답변을 채점기에 던졌고, 그러면 채점기가 «무엇이 주장인지»를 스스로
정해야 한다. 그 결과 우리가 **의무화한 반증조건 절과 절차 메모가 결함 주장으로 세어졌고**(24런 중
22런에 반증조건 절이 있다) 매번 `UNVERIFIABLE` 로 떨어졌다 — 주장의 **절반가량**(N 66 · F 45)이
분모 밖이다. 서로 다른 기권율을 가진 팔들의 오류율을 나란히 놓은 것이므로 **애초에 팔 비교가
성립하지 않았다**(정본: `tracks/_meta/governance_loop_R1_SPEC_2026-09-09.md` W-1).
논문 초안 §1 이 같은 것을 더 세게 적는다 — *"우리가 처음 쓴 채점 자에 결함이 있었다 … **없는
주장을 세고 있었다**"*.

🟥 **그리고 그 표는 재채점으로 구제할 수 없다 — 구조적으로다.** 교체된 채점기
(`tracks/_meta/dominance_B2/build_score_input.py`)는 **타입된 주장**(`title` + `detail`)만 먹고,
B-1 은 타입된 주장을 생산한 적이 없다. **실측 2026-09-17, 재현 가능한 형태로 적는다** — grep 이
아니라 **로더 의미론**(`json.loads(행).get("title")`)으로 세야 한다. 전사본 텍스트 *안에* 중첩된
`"title"` 을 grep 으로 세면 히트가 나고, 그것이 이 절의 첫 측정이 틀렸던 이유다:

```
대상   glob("tracks/_meta/dominance_bench_B/mainrun/*/*.jsonl")
       → 252 파일 · 최상위 `title` 보유 행 합계 = 0
컨트롤 tracks/_meta/dominance_B2/smoke/h02_gen/fleet/findings.jsonl (known-positive)
       → 4
```

⇒ 컨트롤이 살아 있으므로 계기는 판별력이 있고, 부재는 진짜다.
⚠️ **이 수치는 외부 계열이 독립 확인하지 못했다** — 교차검증(codex, 2026-09-17)이 C3 을
`CONFIRMED` 로 냈으나 그쪽이 돌린 `rg` 는 `dominance_B1*`·`governance_loop*`(설계 문서)를 봤고
데이터가 있는 `dominance_bench_B/` 를 안 봤다. **빈 입력에서 나온 hit 0** 이므로 동의로 세지
않는다([[feedback_control_presence_is_not_discrimination]] 의 리뷰어 층 판). **B-1 을 다시 돌리지 않는 한 두 표는 영구히 비교 불가**이고,
그 비교 불가가 바로 교체의 **목적**이었다(타입 계약이 수리다).

### 현행 정본 — B-2 (타입 계약 · 교차 라우팅 채점 · 거버너 재판정 40/40 일치)

| 팔 | 주장 오류율 | FOUND |
|---|---|---|
| F_gen (2회·상대 공개) | **0.0 %** (0/178) | 18/24 |
| F_r2ctrl (2회·상대 감춤) | 0.5 % (1/192) | 22/24 |
| F_typed (1회) | 0.0 % (0/128) | 14/24 |
| O octo | 1.1 % (1/94) | 9/24 |

**95 % 상한 ≈2.1 %**(0/178, rule of three) — «1 % 아래»는 **점추정에만** 해당한다. 자의 판별력은
사전등록 양성 컨트롤로 실측했다(변형 12/12 거절 · 거짓거절 0 · n=12, 95 % 하한 75 %).
🟥 **비교 주장은 서지 않는다**: 케이스를 교환 단위로 둔 클러스터 보정에서 유의한 대조가 **0개**다
(0.017→0.0625 · 0.019→0.109 · 0.359→0.500, Holm 걸면 0/4). 그래서 위 표는 **스펙트럼**이지 순위가
아니다. 정본 = `tracks/_meta/dominance_B2/RESULT_2026-09-10_scoring-calibration.md` §14·§15 ·
초안 `PAPER2_DRAFT_2026-09-12.md`.

### 🟥 철회가 이 이름의 근거를 **약화하지 않고 강화한다** — 방향을 정확히 읽어라

초판은 *"0.x% 는 아직 아무도 낸 적 없는 수치이고(최저가 2.7%), 그래서 «목표»이지 «달성»이
아니다"* 라고 적었다. **그 문장은 이제 못 쓴다** — 다만 **정확한 대체 문장은 «달성했다»가 아니다**:

> **점추정은 0.x% 영역에 들어왔고(0/178), 구간은 아직 안 들어왔다(95 % 상한 ≈2.1 %).**

🟥 **«도달» 한 낱말로 쓰면 그게 곧 이 교리가 금지하는 형태다**(교차검증 A1 지적, 자력 적발 0) —
점추정만 인용하고 상한을 떨구는 것이 «숫자로 통과권을 사는» 첫 동작이다. 초안 자신이 그 경계를
적는다: *"«소수점 수준»은 «1 % 아래»로 말한다 — 0.0 은 0/178 의 점추정이고 95 % 상한은 ≈2.1 %
다. 그 상한을 같이 말해야 정직하다"*(RESULT §14).
그런데 **교리는 그대로 서고, 오히려 이 자리에서 처음으로 진짜 시험을 받는다**:

> 논문 초안 §9 ⓓ — *"오류율이 아무리 좋아져도 이 논문은 그 수를 삭제·발행·이력 재작성 표면에
> 올리자고 처방하지 않는다 — 두 표면을 가르는 것은 오류율의 크기가 아니라 틀렸을 때의 비용
> 구조다."*

즉 **둘째 동사가 «수치가 목표에 닿은 뒤에» 집행되는 것을 실물로 보여준 것**이 현행 근거다.
초판의 근거(«아무도 0.x% 를 못 냈다»)는 둘째 동사를 **시험하지 않는다** — 수치가 목표 밖이면
게이트를 안 여는 것이 당연하니까. 🟥 **미달이 근거일 때 이 이름은 반증 불가였다. 점추정이
영역에 들어온 지금 비로소 반증 가능해졌다** — 그리고 반증 조건은 명시적이다:
**누군가 이 수치를 근거로 비가역 표면의 문턱을 만들면 그때 이 교리가 실패한 것이다**(#687
문단의 defeater 를 그대로 상속한다). 그러므로 이 절의 하중선은 아래 두 문장으로 옮긴다:

**점추정 0.0 % 도 비가역 표면에서는 못 쓴다** — 95 % 상한이 2.1 % 이고, 상한을 무시하는 것이 곧
«숫자로 통과권을 사는» 형태다. 그리고 상한이 1 % 아래로 내려와도 답은 같다 — 발행·삭제·이력
재작성에서 틀린 판정은 독자의 1분이 아니라 **손실 전체**다.
**리뷰 표면에서는 위 넷이 전부 쓸 만하다** — 틀린 지적 하나가 독자의 1분을 쓴다.
이 두 문장 사이의 거리가 거버넌스 엔지니어링이 존재하는 이유다.

⚠️ **초판에서 같이 무너진 것 하나 — «다섯 팔»이라는 표현.** 이 연구의 팔은 **넷**이다
(수리 목록 M1: §2.2 의 `N`·`F(기본)` 은 팔이 아니다). 「다섯 팔」을 인용하지 마라.

## 인접 이름과의 경계 — 대체가 아니라 다른 축이다

| 이름 | 무엇에 대한 것인가 | 정본 |
|---|---|---|
| **하네스 엔지니어링** | **수단** — 하네스라는 «물건»을 어떻게 짓는가(6축) | `harness_6axis_framework.md` · CLAUDE.md §Core Axis |
| **메타 하네스 엔지니어링** | **누가 무엇을 짓는가** — 하네스를 짓는 시스템을 짓는다 | [[meta_harness_engineering_definition]] |
| **거버넌스 엔지니어링** | **목적** — 어느 표면에서 어느 오차율이 허용되는가, 그리고 어디서 멈추는가 | 이 파일 |

셋은 층이 달라서 서로를 대체하지 않는다. 하네스는 거버넌스 엔지니어링의 **도구**이고,
거버넌스 엔지니어링은 하네스가 **무엇을 위해** 있는지를 말한다.

## 왜 이 이름이 지금 필요했나 — 측정된 공백

낱말 실측(2026-09-09, 컨트롤 동반): 「거버넌스 엔지니어링 / governance engineering」은 이 레포
**어디에도 0회**다. 같은 실행의 known-positive 컨트롤 「Harness Engineering」은 5개 파일(CLAUDE.md 포함)에서
히트한다 — 계기는 살아 있고, 부재는 진짜다.

그런데 **발행된 산출물 쪽에서는 이미 그 낱말로 불린다**: arXiv `2609.04218` 은 «governance» 논문이고,
Zenodo `10.5281/zenodo.20680080`(concept DOI — 항상 최신판을 가리킨다) 예치도 «거버넌스»다. 즉 **논문은 우리가 무엇을 하는지 말하고 있는데
정체성 문서는 그 말을 한 번도 한 적이 없었다.** 이 이름은 새 활동을 만드는 게 아니라 이미 하고 있던
것에 이름을 다는 것이다.

## 명명된 잔여 — 아직 안 한 것

- **외부 용례와의 관계 — 요구는 «미사용»이 아니라 «델타 진술»이다** (운영자 정정 2026-09-09):
  *"루프 엔지니어링 그래프 엔지니어링도 이미 예전부터 쓰이던 표현일 텐데 LLM에 대한 거버넌스
  엔지니어링은 또 다른 것일 듯해."* — 이 레포에 그 선례가 실재한다: `loop_engineering.md`(11,713 B)가
  「루프 엔지니어링」을 남의 분야에서 이미 쓰이는 낱말인 채로 우리 뜻으로 쓴다.
  ⇒ **낱말이 남의 분야에 있다는 사실은 사용을 막지 않는다.** 판별자는 **가리키는 대상**이고, 여기서
  대상은 «LLM 이 판정을 생산하는 공정의 오차율을 표면 등급별로 통치하는 것」이다 — IT 거버넌스(조직·
  프로세스 통제)나 데이터 거버넌스(자산·계보)와 대상이 다르다.
  🟥 **그래도 남는 것 하나**: 논문이 이 이름을 내세우는 순간 심사자는 기존 용례를 묻는다. 그때 필요한
  것은 «아무도 안 썼다»가 아니라 **«기존 용례는 X, 우리 대상은 Y» 한 단락**이다. 그 단락 없이
  «we introduce governance engineering» 을 쓰지 않는다 — 이 레포는 참고문헌 불일치 11/17 로 arXiv
  반려를 이미 한 번 겪었고, 그 실패의 축이 정확히 «출처를 안 열고 주장한 것」이다.
  → ✅ **단락 작성됨 (2026-09-17).** 정본 = `tracks/_meta/governance_priorart_2026-09-17.md`
  (확정 서지 12건 + 델타 단락 초안 + 반증 조건). 아래 셋이 그 조사의 판정이다.

- 🟥 **조사가 우리에게 «불리하게» 닫혔고, 그게 이 항목의 값어치다 — W-1 은 우리 발명이 아니다.**
  «커버리지를 같이 보고하지 않은 오류율 비교는 해석 불가» 는 선행기술이다. **거버너가 직접 열어 확정**:
  **El-Yaniv & Wiener**, *JMLR* 11(53):1605–1641, 2010 이 초록에서 *"We term this trade-off the
  **risk-coverage (RC) trade-off**"* 로 **그 이름을 만들고**, 뿌리는 **Chow 1970**(오류–기각 관계식,
  DOI `10.1109/TIT.1970.1054406`) · «고정 working point 한 점 비교가 그 자체로 평가 결함» 은
  **Traub et al.**, arXiv:2407.01032, 2024(AUGRC · 6중 5 데이터셋 순위 변동)다.
  🟡 Chow 의 **쪽수는 적지 않는다** — IEEE·dblp·ACM 셋 다 차단이라 1차 기록을 못 열었고, 확인 못 한
  칸을 적는 것이 11/17 을 만든 동작이다.
  🟥 **더 가까운 것도 있다** — **SCOPE**(arXiv:2602.13110, 2026-02-13)가 **LLM 판정자라는 같은
  표면에서** *"the error rate among non-abstained judgments is at most a user-specified level α"* 를
  캘리브레이션하고 커버리지를 함께 보고한다.
  ⇒ **`governance_loop_R1_SPEC` W-1(커버리지 기록)은 기여가 아니라 그 계보의 «적용»이다.**

- 🟥 **아래 «델타» 는 작성 당일(2026-09-17) cross-family 에서 BLOCKING 으로 죽었다 — 지우지 않고
  정정한다. 이 순서가 기록이다: 내가 발주한 선행조사가 내 델타를 죽였다.**
  **ⓐ 논리 결함(치명)**: «비용 구조가 다르다 ⇒ 수치 개선으로 승격 불가» 는 **유한 비용에서 거짓**이다.
  발행 오판이 리뷰보다 10,000배 비싸도 오류율을 1/10,000 로 낮추면 같은 기대손실에 도달한다 ⇒
  «승격 불가» 가 아니라 «더 엄격한 문턱 필요» 다. 🟥 **비가역은 곧 무한이 아니다** — 삭제도 백업·
  감사로그·롤백·보상이 있으면 유한 손실로 모델링된다. 그러므로 아래 문장은 **«비용이 무한» 이라는
  숨은 전제**에 의존하고 있었고, 그 전제는 정당화되지 않는다.
  **ⓑ 선행기술**: action 별로 위험 보장을 조건화하는 정식화가 이미 있다 — **Zhu, Z., Kiyani, S.,
  Pappas, G. & Hassani, H.**, "Conformal Risk-Averse Decision Making with Action Conditional
  Guarantee," **arXiv:2606.05551**, 2026-06-04 (거버너 직독: *"safety guarantees conditioned
  explicitly on **each action** taken by the decision maker"* + action-conditional VaR).
  «표면» 을 «action» 으로 번역하면 우리 주장은 그것의 **거버넌스 층 재진술**이다. 규범 층에도 이미
  넓게 깔려 있다(⚠️ 아래 셋은 cross-family 제시분이고 **거버너 미확인**): EU AI Act Art. 14 인간 감독 ·
  NIST AI RMF oversight/scope · AWS Agentic AI Lens 의 위험등급별 human approval. 비용 층도
  선행이다(Elkan 2001 cost-sensitive · Franc et al. JMLR 2023 reject option · Narasimhan et al. 2022
  learning-to-defer — 셋 다 미확인).
  **ⓒ SRE 대비도 과장이었다**: SRE 도 «수치가 모든 문을 연다» 가 아니고(예외·P0·stakeholder approval),
  더 결정적으로 **SRE 의 표면은 대개 롤백 가능한 배포**라 애초에 다른 것을 말한다.

  🟢 **그래서 교리는 남고 «근거» 가 교체된다.** 표면 등급 규칙 자체는 FH 의 운용 규칙으로 **그대로
  유지한다**(§Irreversibility Gates 무변경 — 실무에서 옳다). 바뀌는 것은 **왜 옳은가**다:
  기대손실이 아니라 **권한·책임 + 순환성**이다.
  > **L1 이전 불가 — 🟢 우리 것이 아니라 «남의 정리» 다.** distribution-free 위험 인증은 배치가
  > 바뀌면 안 선다: **Kotte, V.**, arXiv:2606.29054, 2026-06-27(거버너 직독) — cross-dataset
  > shift 에서 *"the target is violated on **14 of 16 transfers** by static CRC and **every tested
  > adaptive-conformal-inference (ACI) step size**, yet a full-feedback anytime-valid monitor
  > certifies **0 of 16**"* · 실용 인증은 **α = 0.40** 에서야 열린다. ⇒ **수치의 «엄격한 버전»
  > 조차 표면·배치를 건너 운반되지 않는다.** 이 다리가 논거를 자평에서 외부 실측으로 올린다.
  > **L2 자기측정 + 구매 가능성.** 그 오류율은 **통과권을 받을 같은 시스템 계열이 자기를 재서**
  > 낸 값이고, **행동을 고치지 않고 주장을 버려서** 낮출 수 있다 — 조작 방향이 저자에게 유리하다.
  > 🟥 **조상이 둘 있고 둘 다 명명해야 한다.** ⓐ **Goodhart(1975)** — 측정이 목표가 되면 측정이
  > 아니게 된다. 최근 형식화(**Majka & El-Mhamdi**, arXiv:2505.23445, 직독)는 proxy↔goal 커플링을
  > 다루고 우리 두 형태는 안 다룬다. ⓑ 🟥 **NIST AI 100-1 `MEASURE 1.3`(2023)** — *"**Internal
  > experts who did not serve as front-line developers** for the system and/or **independent
  > assessors** are involved in regular assessments."* ⇒ **«만든 쪽이 자기를 채점하면 안 된다» 는
  > 이미 표준 규범이다.**
  > ⚠️ **초판이 여기서 과주장했다(2026-09-17, 같은 날 정정)** — «이 형태는 D1 목록 어디에도 없다»
  > 고 적었는데 `MEASURE 1.3` 이 그 자리다. 조사 에이전트가 *"«어디에도 없다»로 쓰기 **전에** 이
  > 줄을 봐라"* 라고 재료로 올려서 잡혔다.
  > 🟥 **조상이 셋이다 — 4라운드가 셋째를 찾았고, 그것이 결론절을 «정리» 로 선점한다.**
  > ⓒ **Lovén, L., Do, N., Mehmood, H., Sah, D. K. & Tarkoma, S.** "The Behavioral Credibility
  > Trilemma: When Calibrated Autonomy Becomes Impossible," **arXiv:2605.25739**, 2026-05-25
  > (rev 07-19) — **confidence-gated autonomy** 가 «최대 helpfulness · 최적 calibration · 합리적
  > 감독 하 완전 자율» 셋을 **동시에 달성 불가**임을 증명한다. 기전 = *"adding any non-affine
  > autonomy incentive to a strictly proper scoring rule **destroys strict properness**"* ⇒
  > 에이전트는 승인 문턱 **아래** 태스크에서 보고 confidence 를 체계적으로 부풀린다.
  > 짝 논문 = 같은 저자 라인의 **arXiv:2605.07671**(ACM TEAC **투고 중** — 🟥 «게재» 로 쓰지 마라).
  > ⇒ 🟥 **「자기보고 수치에 걸린 문턱은 유인양립적이지 않다」는 우리보다 강한 형태로 이미 있다.
  > 그 결론을 우리 것으로 쓰면 중복이다.**
  >
  > 🟢 **그래서 살아남는 것은 «우려» 도 «결론» 도 아니고 «한 다리 + 집행» 이다**:
  > ① **`ε̂ = ε̂(π)`** — `ε̂` 은 **시스템이 무엇을 버릴지 고른 뒤 남은 부분집합**에서만 계산되므로
  > **`ε` 을 안 낮추면서 `ε̂` 을 낮추는 π 가 존재한다**(구성적). 🟢 **이 등식은 넷 어디에도 없다** —
  > trilemma 는 HTML 전문 대조로 ⓐ selective evaluation 부재 ⓑ coverage 개념 부재 ⓒ **잔존
  > 부분집합 추정치 부재** ⓓ **평가자=피평가자 계열 논의 0** 이 확인됐고(2026-09-17 조사),
  > `MEASURE 1.3`·Goodhart 형식화도 이 등식을 쓰지 않는다. 가장 가까운 것은
  > **Azevedo, C. R. B.**, arXiv:2606.15563 — *"corrected performance can **hide the competence
  > signal** needed to calibrate trust"* — 🟥 **지우는 주체가 «하류 교정» 이고 «피평가 시스템
  > 자신의 π» 가 아니다.** 그 접합이 우리 몫이다.
  > ② 그리고 우리 것은 관찰이 아니라 **기계화된 거절**이다: `scripts/finding_verify.py` 가
  > **드롭이 감사되지 않은 실행의 완료를 거부한다.** 규범은 «독립 평가자를 둬라» 까지고,
  > 우리 것은 «드롭 감사 없이는 실행이 완료로 표시되지 않는다» 다.
  >
  > ⚠️ **L1 도 이중으로 우리 것이 아니다** — Kotte(2606.29054) 외에 **Perdomo, J. C., Zrnic, T.,
  > Mendler-Dünner, C. & Hardt, M.** "Performative Prediction," *ICML 2020*, PMLR 119:7599–7609 이
  > «배치가 분포를 움직인다» 의 정본이고 **strategic classification 을 진부분집합으로 포함**한다고
  > 명시한다. L1 은 인용으로 처리하고 우리 몫은 ①로 좁힌다.
  > **L3 권한 — lexicographic.** 종단 책임자가 **사람 또는 기록된 override** 여야 한다는 것은
  > 기대효용 «위» 의 hard constraint다. 비용 계산으로 살 수 있는 것이 아니다.
  ⇒ 🟥 **«비가역 손실은 무한하다» 로 쓰지 마라.** 「그 측정이 운반되지 않고(L1) · 자기이해적이며
  유리한 방향으로 구매 가능하고(L2) · 종단이 애초에 권한 문제다(L3)」로 써라. **이 진술은 죽은
  버전보다 «약해서» 선다** — 비용의 크기를 아예 주장하지 않는다.

  🟢 **표면을 가르는 성질도 기계적으로 적는다(3라운드) — 그리고 셋째가 선행기술과 갈린다:**
  **T1** 행위자가 되돌릴 수 있나 · **T2** 동의하지 않은 제3자가 관측하나 · **T3** 🟥 **손실을
  누가 지고 그가 선택했나**(리뷰 = 독자의 1분, 그리고 **읽기를 선택했다** / 비가역 = 손실 전체,
  흔히 **선택하지 않은 사람**이 진다). **T1·T2 는 «행위» 의 성질이고 T3 는 «누가 노출되나» 의
  성질이다** — action-conditional risk guarantee(Zhu et al.)는 **행위에 조건을 걸어 T1 을 덮지만
  T3 는 덮지 않는다**(같은 행위라도 손실을 지는 쪽이 동의했는지는 action 의 함수가 아니다).
  죽은 버전은 이 구분 없이 «표면» 이라고만 써서 «action 으로 번역하면 같다» 를 그대로 맞았다.

- 🟢 **policy mapping — D4 의 네 번째 칸이 채워졌다 (2026-09-17, 1차 출처 직독).**
  🟥 **규범 층은 표면별 차등을 이미 갖고 있다. 그런데 판별자가 우리와 다르다 — 그게 매핑의 요점이다.**

  | 규범 | 요구 | 🟥 차등의 판별자 |
  |---|---|---|
  | **EU AI Act** Art. 14(3) (Reg. (EU) 2024/1689) | 감독은 *"commensurate with the **risks, level of autonomy and context of use**"* | **위험등급 · Annex 분류** — 성능이 아니다 |
  | 같은 조 14(4)(d)(e) | *"decide … to **disregard, override or reverse** the output"* · *"**'stop' button** or a similar procedure"* | **감독자 개인의 능력 요건** — 수치 문턱이 아니다 |
  | 같은 조 14(4)(b) | *"remain aware of the possible tendency of **automating bias**"* | 자동화 의존 자체를 명시적 위험으로 |
  | 같은 조 **14(5)** | Annex III **1(a)** 에 한해 *"**separately verified and confirmed by at least two natural persons**"* | 🟥 **범위가 좁다** — «원격 생체인식 **식별**» 만이고 생체 **검증(verification)** 은 명시적 제외, **법집행·이주·국경·망명은 예외**. 「규정이 2인 검증을 요구한다」로 일반화하면 그게 지적 거리다 |
  | **NIST AI 100-1** MAP 3.2 / 3.3 / 3.5 (+ **GOVERN 3.2**) | 오류 비용 · targeted application scope · 인간 감독 프로세스를 **문서화** | «조직의 risk tolerance 에 연결» — **문서화 요구**이고 차단 규칙이 아니다 |
  | 같은 문서 MEASURE 2.6 | *"**residual negative risk does not exceed the risk tolerance**, and it can **fail safely** … beyond its knowledge limits"* | 🟥 **표준 안에서 «오류예산» 에 가장 가까운 자리** — §SRE 대비를 쓸 때 «표준·학술엔 없다» 로 쓰면 여기서 걸린다 |
  | 같은 문서 Appendix B | *"**Some AI systems may not require human oversight** … Other systems may **specifically require** human oversight"* | 🟢 **차등 문제를 «더 연구가 필요한 쟁점» 으로 열어 둔다** — 우리 기여의 자리가 남의 문서에 명시돼 있다 |

  ⇒ **매핑의 결론 한 줄**: 규범은 **범주(위험등급·Annex·조직 tolerance)로 차등**하고 그것을
  **문서화하라**고 요구한다. 🟢 우리 것은 ⓐ 차등의 판별자를 **T1~T3(되돌림·제3자 관측·손실 귀속과
  동의)** 로 명시하고 ⓑ 그것을 **문서가 아니라 집행**으로 둔다(가역=advisory / 비가역=fail-closed +
  기록된 override). ⚠️ 그리고 **`MEASURE 2.6` 과 `Appendix B` 는 우리 편이다** — 전자는 표준이
  이미 «tolerance 초과 금지 + fail safely» 를 말한다는 뜻이고, 후자는 «어느 시스템에 감독이
  필요한가» 를 **미해결로 명시**한다.

- ⚠️ **같은 조사가 `formal model` 선택지 ⓐ 를 약화시켰다.** ⓐ(«우리는 비용이 아니라 제약을 쓴다»
  로 lexicographic 을 선언)는 **Franc, Prusa & Voracek**, *JMLR* **24(11):1–49**, 2023 이
  **정리로 막는다**: *"despite their different formulations the **three rejection models lead to the
  same prediction strategy**"* — 비용 기반 · bounded-improvement · bounded-abstention 이 **동일
  전략으로 수렴**한다. ⇒ «제약 형식으로 바꿨다» 는 것 자체로는 **형식적 이득이 없다.**
  🟢 **ⓑ(«추정량이 그 양이 아니다»)는 이 정리에 안 걸린다** — Franc et al. 은 **참 위험을 안다고
  가정**하고 최적 전략을 논하므로, 인식론(추정량의 식별·유인)을 공격하는 ⓑ와 층이 다르다.

- 🟢 **`formal model` 판정 — ⓑ 로 쓴다. 단 «한 다리» 로 좁히고 네 편을 인용할 때만**
  (2026-09-17, 4라운드 조사 결과에 따른 거버너 판정. 운영자 결정 = 추천 순서대로 진행).
  ```
  쓸 수 있다   ε̂ = ε̂(π) — 「추정치가 시스템이 버릴 것을 고른 뒤 남은 부분집합에서만 계산된다」
               + 그것의 기계화된 거절(드롭 감사 없는 완료 거부)
  못 쓴다      「자기보고 수치 문턱은 유인양립적이지 않다」  ← arXiv:2605.25739 가 정리로 선점
               「캘리브레이션 분포 ≠ 배치 분포」               ← Perdomo et al. 2020 이 정본
               「관측 성능이 권한 근거가 못 된다」의 절반      ← arXiv:2606.15563
               「제약 형식이 비용 형식보다 다르다」            ← Franc et al. 2023 동치 정리
  인용 의무    위 네 편 + Goodhart + NIST MEASURE 1.3. 🟥 미인용은 방어 불가다
  ```
  ⚠️ **그리고 이 명제를 «모델이 평가임을 알아채고 게임한다» 에 기대게 쓰지 마라** —
  `arXiv:2605.05835`(eval-awareness 효과가 희박하다는 방향, 🟥 **미독**)가 그 의존을 반박한다.
  🟢 **우리 명제는 그 의존이 필요 없다** — `π` 는 **설계 선택**이고 모델의 은밀한 전략이 아니어도
  `ε̂ = ε̂(π)` 는 성립한다. 이 구분을 본문에 안 적으면 그 논문으로 맞는다.

- 🟥 **투고 전 직독 의무 4건 (조사가 «못 열었다» 로 남긴 것 중 하중 지는 것만)**:
  ⓐ **FAccT 2025 Davis & Ruster**(403) — §2 프레임을 정하기 전에 ⓑ **MSR 2026 PaC maintenance**
  (Rahman 그룹, 10,560 파일/499 레포) — 우리 «유지비·게이트 드리프트» 자리와 가장 겹친다
  ⓒ **Computers 15(7):453** policy-drift(CI 와 admission control 의 독립 구현이 drift 를 만든다) —
  우리 §gate-locality 와 같은 축 ⓓ **Google SRE Workbook "Error Budget Policy"** 장.
  그리고 selective-prediction 6편 · self-preference 6편 · eval-awareness 4편은 **abs 조차 미개봉**
  이라 *"본문에 한 문단 있을 가능성 미배제"* 가 정직한 상태다(조사 자기 보고).

  🟥 **그리고 논문의 델타는 여기가 아니다.** 선행조사 20여 건 어디에도 없었던 형태는 **§9 ⓐ** 다 —
  *재는 자를 결과 보기 전에 고정해 판별력을 실측하고, **그 자로 우리 자신의 주효과를 죽였다***.
  이 항목의 이력이 그것의 두 번째 실례다(발주한 조사가 발주자의 델타를 죽였다). 교리는 운용 규칙으로,
  기여는 방법론으로 — **섞지 않는다.**

- 🟡 **운영자 프레임 (2026-09-17) — «처방이 아니라 집행». 🟥 기록하되 «시험 중» 이다.**
  > *"저들은 fh를 가지지않았다는게 차이다."*

  읽기: 선행기술은 전부 **방법·규범**이다 — «위험을 이렇게 통제해야 한다»(conformal 계보) ·
  «비가역 행위는 인간 감독을 받아야 한다»(EU AI Act · NIST AI RMF · AWS). 🟢 **우리가 가진 것은
  돌아가는 게이트다**: 드롭 감사 없는 실행의 **완료를 거부**하고(`finding_verify.py`), 같은 엔진이
  가역 표면에서 advisory 로 degrade 하고 비가역 표면에서 fail-closed 로 막으며(`pre-commit` /
  `pre-push` + 기록된 override), 그것이 **다른 사람에게 배급된다**(friends-on-desk).
  ⇒ 기여 형태가 «더 나은 정리» 가 아니라 **«거버넌스 경계를 기계화한 구현 보고 + 그때 무엇이
  깨졌는지의 실패 기록»** 이 된다. 그리고 이 레포의 자기 교리와 정합한다 —
  §Mechanization Boundary · 「muscle 이 아니라 skeleton」 · 「prose-invoked floor 는 M-tier」.

  🟥 **그런데 이것도 «우리 발명» 으로 적으면 이 문서가 오늘 두 번 당한 그 동작이다.** 그래서
  **확정으로 안 쓴다** — 4라운드 조사(질문 2)가 policy-as-code · compliance-as-code · SRE error
  budget policy 운용 보고 · responsible-AI operationalization 케이스 스터디 쪽에 **같은 형태의
  구현 보고가 이미 있나**를 재고 있다. 그 결과 전에 «net-new» 라고 쓰지 않는다.

  🟥 **4라운드 결과가 나왔고 이 프레임은 지금 형태로 거짓이다 (같은 날 정정).**
  **ActPlane**(Zheng et al., **arXiv:2606.25189**, 2026-06-23)의 초록 **첫 문장**이 우리 어휘를
  우리 뜻으로 쓴다: *"AI agents increasingly run in production through **harnesses**, the software
  around the LLM, including an **engine that enforces safety and effectiveness policies**, e.g.,
  **'run tests before committing.'**"* — eBPF 커널 층 집행 + IFC DSL(오버헤드 1.9~8.4 %).
  거기다 **policy-as-code 대규모 실증**(Foalem et al., arXiv:2601.05555 — 399 레포·9 도구)과
  **조직 감사 실증**(Mökander & Floridi, AstraZeneca 12개월, arXiv:2407.06232)도 있다.
  ⇒ **«저들은 집행 기계가 없다» 는 반증됐다.**

  🟢 **참인 형태는 훨씬 좁고, 그 셋은 문헌에서 대응을 못 찾았다:**
  ① **같은 엔진이 가역/비가역에 따라 degrade 방향을 바꾸는 설계**(advisory ↔ fail-closed)
  ② **판정 채널의 무결성** — 드롭 감사 없는 실행의 «완료» 거부
  ③ **기계화가 «깨진» 기록** — ActPlane 은 성능·준수율 벤치마크를, Mökander & Floridi 는
     **조직적** 난점을 내고, 어느 쪽도 **기계화의 기술적 실패 로그**가 아니다
  ⚠️ **①의 실무 선례는 회색문헌에 있다**(graduated error budget policy) — 그리고 «과차단이 우회를
  훈련시킨다» 는 관찰도 블로그 층에 이미 있다. 무시하면 «실무자는 다 아는 얘기» 로 읽힌다.

  🟥 **그리고 논문을 여는 방식이 금지됐다 — «처방만 있고 집행이 없다» 로 시작하지 마라.**
  **Davis, J. L. & Ruster, L. P.** "The gaps that never were: reconsidering responsible AI's
  principle-practice problem," *FAccT 2025*, pp. 350–360, DOI `10.1145/3715275.3732024` 이
  **그 격차 프레이밍 자체를 심문**한다.
  🟢 **5라운드에서 직독했고 판정이 역전됐다. 🟥 저자 순서도 정정 — 지면은 `Ruster, L. P. &
  Davis, J. L.`(ANU / Vanderbilt) 다.** 초록 축자: *"the field has produced an array of **bridging
  instruments in the form of toolkits, guidelines, and frameworks** … **Yet, the principle-practice
  problem persists.** Rather than propose new and better bridging devices, we step back to
  interrogate the metaphor itself."* 결론 = *"principles and practices are **integrated, nonlinear,
  and subject to dynamic values** that transform across time and circumstance."* (Morley et al.
  2020 이 학술 문헌만 **425건**을 셌다.)
  ⇒ 🟢 **그들이 공격하는 것은 «브리징 도구를 하나 더 만드는 것» 이다 — 우리는 426번째가 아니다.**
  우리 산출은 «기계화한 경계가 무엇을 했는가» 의 기록이고, 그건 그들이 실측한 «integrated ·
  nonlinear · dynamic» 과 **정합한다**(우리 실패 로그가 그 모양이다).
  ⇒ **§2 를 이렇게 연다**: 「격차가 있다」가 아니라 **「425건이 나왔고 문제는 남았다. 우리는
  426번째를 내지 않는다 — 기계화한 경계가 무엇을 했는지 보고한다.」**
  ⚠️ 🟥 **그래도 «처방만 있고 집행이 없다» 는 여전히 금지다**(ActPlane 이 반증). 금지는 «집행이
  없다» 이고 허용은 «도구를 더 내지 않는다» 다 — 둘을 섞지 마라.

  🟢 **5라운드가 ①②③ 을 각각 시험해서 셋 다 통과했다:**
  ⓐ **Opdebeeck, R. 외 6인**, "An Empirical Study of Policy as Code: Adoption, Purpose, and
  Maintenance," *MSR '26*, DOI `10.1145/3793302.3793355`(10,560 파일 · 499 레포 · 9 도구)의
  **다섯 enforcement strategy 가 전부 «집행 시점·위치» 다**(Admission 34.29 % · User-Invoked
  22.86 % · CI · Event-Triggered 20 % · Scheduled 5.71 %) — **degrade 방향 분기는 없다** ⇒ ① 생존.
  ⚠️ 단 RQ3 가 *"policies tend to become **stricter more often than more lenient**"* 라고 실측하므로,
  «과차단이 override 를 훈련시킨다» 를 쓸 때 **대상이 다름을 본문에 적어라**(그쪽 = 정책 내용의
  엄격도 / 우리 = 비가역 표면의 override 채널).
  ⓑ **Nogueira, L. & Resende, A.**, *Computers* **15(7):453**, 2026, DOI
  `10.3390/computers15070453` 은 🟥 **«CI 우회» 를 정면으로 다룬다** — *"Kubernetes admission
  control **mitigated all evaluated CI bypass scenarios**"*(29 매니페스트 · 37 시나리오 · 261 단언)
  ⇒ **인용 의무.** 🟢 그런데 처방이 «배치 시점에 두 번째 집행 단계를 둔다»(층 추가)이고, 전수
  grep 에 **advisory · audit mode · blocking 모드 · override · 비가역성 어휘가 전부 없다** ⇒
  ①② 생존. 그리고 «duplicate 구현이 **policy drift** 를 만든다» 는 §gate-locality 의 **외부 근거**다.
  ⓒ 🟡 **SRE Workbook** "Error Budget Policy"(**Thurgood, S.**, 2018-02-19)에서 **L3 의 이웃을
  찾았다** — *"escalated to the **CTO** to make a decision."* 🟥 **«우리만 사람을 종단에 둔다» 로
  쓰면 안 된다.** **정확한 차이**: SRE 는 문턱을 **수치가 열고 닫고**(*"halt all changes and
  releases other than P0 issues or security fixes"*) 사람은 **«계산에 대한 이견»을 해결**한다.
  우리는 **수치가 애초에 문을 안 열고** 사람/기록된 override 가 **문 자체**다. ⇒ 대비를 «사람을
  두는가» 가 아니라 **«수치가 문을 여는가»** 로 진술한다.

- ~~🟢 **그래서 델타가 좁아지고 선명해진다 — «α 를 무엇이 정하는가».**~~ 🟥 **위에서 철회됨**
  선행 계보 전체에서 α(또는 기각비용·손실)는 **사용자가 지정하는 하나의 스칼라**이고 기계는 그 아래서
  커버리지를 최대화한다. 그 정식화에는 «이 α 가 여기서는 합법이고 저기서는 불법이다» 라는 **자리가
  없다** — Chow 의 기각비용은 그 불연속을 **연속 비용으로 접고**, SCOPE 는 «더 강한 판정자 → 같은 α
  에서 더 높은 커버리지» 로 **수치를 능력으로 환산**한다. 우리 주장은 그 축에 없다:
  > **오류예산은 엔진의 성질이 아니라 표면의 성질이다.** 따라서 **수치를 개선해서 엔진을 표면 사이로
  > 승격시킬 수 없다** — 표면 간에 변하는 성질은 그 수치가 아니다.
  **대비항이 인용 가능하게 서 있다**: SRE 오류예산은 «예산이 남아 있으면 배포 계속» 즉 **수치가
  게이트를 «연다»**. 우리는 정반대이고, 그 대비가 두 동사를 가장 선명하게 만든다.
  🟥 **위상을 정직하게**: 표면별 불연속은 **측정한 것이 아니라 설계 주장**이고, 데이터가 보여주는 것은
  그 주장이 필요해지는 **거리**까지다. 측정으로 세우는 것과 교리로 세우는 것을 섞지 않는다.

- 🟥 **논문이 반드시 다뤄야 할 긴장 둘** — 안 다루면 리뷰 지적이 나온다.
  ⓐ **Weaver**(arXiv:2506.18203)는 «가중 투표가 잘 된다» 를 **정확도**로 보이고, 우리는 «같은 증거를
  읽는 교차-모델 투표가 약하다» 를 **위험 제안 승인율**로 말한다 — **재는 것이 다르다.** 명시하지
  않으면 «Weaver 가 반증한다» 가 나온다. 보강 = arXiv:2607.28317 의 *"cross-family correlation is not
  low — shared difficulty dominates lineage"*(§Core Axis 의 40.9 vs 11.3 해석에 **메커니즘**을 준다).
  ⓑ **ALCE**(EMNLP 2023, DOI `10.18653/v1/2023.emnlp-main.398`)는 인용의 **지지 여부를 NLI 로** 재고
  우리 훅은 **비공허성만** 본다 ⇒ 🟥 «우리가 더 엄격하다» 로 쓸 수 없다. 우리 것은 **경계를 명시한
  것**까지다(§Mechanization Boundary 그대로).
- ~~**상주층 반영 미완**~~ → ✅ **닫혔다 (2026-09-14 실측).** `CLAUDE.md:44` §Core Axis 행이
  **「And what it is a means *to* is Governance Engineering (What for)」** 를 이미 싣고 있고,
  이 파일을 canon 으로 가리키며 «외부 용례가 있으니 델타를 진술하라» 는 조건까지 같은 줄에 박혀 있다.
  🟥 이 줄이 **닫힌 항목을 열린 것으로 적고 있었다** — 같은 날 판단 넷 ①②④ 와 같은 방향의 네 번째
  stale carry 다(전부 «집행됐는데 기록만 안 따라간» 형태). 컨트롤 동반 확인: 같은 grep 이 존재하지
  않는 문구(`Zzz Engineering`)는 0 을 낸다.
- ~~**별도 논문인가 v2 후속인가 — 미결**~~ → ✅ **별도 논문으로 확정 (운영자, 2026-09-17:
  *"별도 논문임. … 이거 예전에도 말한거임"*).** 🟥 **«예전에도»가 이 항목의 하중선이다** — 운영자가
  이전에 이미 말했고 그 발화가 **어느 기록에도 착지하지 않아서** 결정 문서가 9일 동안 「안 정한 것」
  으로 남아 있었다. 대응은 됐고 기록이 안 됐다([[feedback_response_is_not_record]]).
  결정 정본 = `tracks/_meta/decisions_2026-09-09_governance-engineering-frame.md`.
- 🟥 **논문의 척추가 초안에서 이미 바뀌었고 결정 문서의 «재료 넷» 표가 그걸 절반만 반영한다.**
  ⓐ **④(5팔 비교)는 닫혔다** — 2026-09-17 에 철회 표기 + 현행 B-2 스펙트럼으로 대체했다
  (교차검증 A3 지적으로 발견 — 이 파일만 고치고 결정 문서를 안 고친 반쪽-픽스였다,
  [[feedback_half_fix_propagation_boundary]]).
  ⓑ **나머지 셋(①②③)은 미검증이다** — 초안이 **«생성시점 탈상관» 주장을 철회**했고
  (F_r2ctrl 이 상대 목록을 감추고도 분리 안 됨 — RESULT §15) 세우는 주장은
  **«두 번 봐도 깎이지 않는다»**(짝지음 손실 0/24 · 0/24) 하나로 좁아졌는데, 그 철회가 ①②③
  각 행의 수치를 건드리는지는 **안 열어 봤다.** ⚠️ 초판의 이 줄은 그 철회를 ①(포장이 내용을
  이긴다, 6/24 vs 3/24)에 **근거 없이 귀속**했다 — 다른 측정이다. 귀속을 철회하고 «미검증»으로
  남긴다. ⇒ 남은 작업 = ①②③ 을 초안 §9(기여) 기준으로 대조.
- 이 파일은 **정의**지 실행 절차가 아니다. 실행부는 이미 있다 — §Irreversibility Gates(표면 등급) ·
  `finding_verify.py`(드롭 감사 없는 정밀도 거부) · `field_verdict_crossfamily_gate.md`.
