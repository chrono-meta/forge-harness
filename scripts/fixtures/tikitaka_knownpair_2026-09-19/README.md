# tikitaka known-pair — 채점기 교정 픽스처 (2026-09-19)

정본 = `tracks/_meta/prereg_2026-09-19_qasp-tikitaka-sim.md` §2-ⓓ.
채점기 = `scripts/tikitaka_score.py` · 레인 = `scripts/test_tikitaka_score_lanes.sh`.

> 🟥 **이 픽스처가 안 갈리면 본측정을 돌리지 않는다** (사전등록 §4 F2).

## 형태는 실물에서 뽑았다 — 머릿속 모형이 아니다

[[feedback_fixture_shape_from_artifact_not_mental_model]]. 전사본 안의 TC 표는
qasp `src/prism/protocols/p7_tc_design.py` 의 실제 산출 형태를 그대로 따른다:

| 실물 | 이 픽스처가 따른 것 |
|---|---|
| `to_markdown_table()` | `\| No \| 대분류 \| 중분류 \| 소분류 \| 서브젝트 \| 사전조건 \| 수행절차 \| 기대결과 \| 비고 \| 중요도 \| 서비스도메인 \| 자동화 \|` — **12 컬럼** |
| `_procedure_text()` | 수행절차는 `1. … / 2. … / 3. 기대결과 확인` (줄바꿈 → `" / "`) |
| 중요도 값 범위 | `P0` · `P1` · `P2` (`p3_tc_review.py` Format 검사와 같은 집합) |
| tc_id 계열 | `TC_F_{n:03d}` · `TC_BVA_{n:03d}` · `TC_SM_{n:03d}` |
| 전사본 감싸개 | `scripts/sim_isolated_run.sh` 의 `===== turn <k> (rc=<n>) =====` |

🟥 **실물과 어긋나는 자리 하나 — 이름으로 적는다.** `to_markdown_table()` 의 컬럼에는
**`tc_id` 가 없다**(내부 dict 에만 있고, 표의 `No` 는 일련번호다). 그래서 이 픽스처는
tc_id 를 **`비고` 칸**에 싣고, `turns.txt` 의 T1 이 *"각 TC 는 비고 칸의 tc_id 로 지칭한다"*
고 **시나리오에서 못박는다**. 채점기가 가정하는 게 아니라 시나리오가 만드는 전제다.
⇒ 본측정 전에 같은 전제를 실제 turns 파일에도 실어야 한다. 안 실으면 항목이 0 개로
잡히고 채점기는 `NO-BASELINE`(rc=3) 으로 **시끄럽게** 죽는다(조용한 통과가 아니다).

🟥 **도메인은 합성이다** — 비밀번호 재설정. 조직 식별자·내부 자산명·실데이터는
한 글자도 들어 있지 않다(CLAUDE.md §company residency).
검증은 눈이 아니라 계기로 했다 — `psa_scan_file` 전수 결과 hit 0(스캐너 생존 컨트롤 rc=1 동반).
🟥 **그 계기가 이 README 의 초판을 실제로 잡았다**(조직 어휘 1건, LOW). 고쳐서 0 이 된 것이지
처음부터 0 이었던 게 아니다. 사전등록 §6-ⓐ 가 남긴
«T1 의 TC 세트를 어디서 가져오나» 는 **여전히 운영자 결정**이고, 이 픽스처는 그 결정을
대신하지 않는다 — 채점기를 교정할 뿐이다.

## 뚫리는 표기 — 일부러 심어둔 것

가장 쉬운 표기를 고르면 결함의 다른 표기를 못 잡는다
([[feedback_fixture_must_use_the_breaking_spelling]]). 세 개를 심었다:

1. **산문 드롭 줄이 «행처럼» 생겼다** — `positive`/`split` 의 turn 3:
   `제외: TC_F_003, TC_BVA_002, TC_BVA_003, TC_BVA_004 — 사유는 각각 …, …, …, …이고, P1 …`
   쉼표 7개(=칸 8개) + `P1` 토큰. **칸 수만 세는 추출기는 이 줄을 «남긴 행» 으로 읽고,
   그러면 C 가 A 와 같아져 C1 이 구조적으로 뒤집힌다.**
2. **T4 가 버린 항목을 산문으로 다시 «언급» 한다** — `positive` turn 4 의
   *"TC_BVA_002·TC_BVA_003 는 이번 계획에 없다"*. 「T4 에 id 가 보이나」로 A1 을 재는
   추출기는 여기서 **거짓 FAIL** 을 낸다. 좋은 실행계획은 범위 밖을 명시하기 때문에
   이건 예외가 아니라 정상 표기다.
3. **중간점 이음** — `TC_BVA_002·TC_BVA_003` 처럼 공백 없이 `·` 로 붙인 표기.

## 다섯 픽스처

| 파일 | 내용 | 기대 등급 | 이 픽스처가 **FAIL 로 검정하는** 조건 |
|---|---|---|---|
| `positive.transcript.txt` | 이상적 티키타카 — C1·C2·C3 전부 명시, T4 가 범위 준수 | `CONVERGED`+`APPLIED` | (전부 PASS — known-positive) |
| `negative.transcript.txt` | 축소만 함 — 목록만 잘리고 버린 것 명명 없음, T4 가 원안 복귀 | `NOT-CONVERGED`+`NOT-APPLIED` | **C3** · **A2** |
| `split.transcript.txt` | 🟥 수렴 O · 반영 X — 절충안은 섰는데 T4 가 버린 걸 되데려온다 | `CONVERGED`+`NOT-APPLIED` | **A1** |
| `c1fail.transcript.txt` | 말만 절충 — «4건 2일 로 맞췄다» 고 해놓고 항목 집합은 원안 그대로 | `NOT-CONVERGED`+`NOT-APPLIED` | **C1** |
| `c2fail.transcript.txt` | 절충은 제대로 했는데 제약을 **수치로** 다시 안 적었다(«절반 정도») | `NOT-CONVERGED`+`APPLIED` | **C2** |

`split` 가 왜 있나: 사전등록 §0 이 *"두 축을 하나로 접으면 그 실패가 보이지 않는다"* 고 적는다.
positive/negative 둘만으로는 **두 축이 같이 움직이는 «접힌 채점기»** 도 통과한다.

🟥 **`c1fail`·`c2fail` 이 왜 있나 — 2026-09-19 적대검증이 연 구멍이다.**
초판은 픽스처 셋이었고 기대를 **등급 두 개**로만 적었다. 그런데 셋 다 `C1=PASS C2=PASS` 였다.
즉 **C1 이 `return "PASS"` 로 하드코딩돼 있어도, C2 가 죽은 로직이어도 known-pair 가 전부
통과했다.** 「3개가 3등급으로 갈린다」는 참이지만 그 갈림은 전적으로 C3·A1·A2 축에서 왔다 —
집계 수준에는 「컨트롤 있음 ≠ 판별력 있음」을 적용했고 **조건 수준에는 안 했다.**
자력 적발 0, cross-check 가 잡았다.
⇒ 이제 `--selftest` 가 조건별 기대를 대조하고, **모든 조건이 PASS 와 FAIL 을 각각 한 번은
낸다**를 강제한다(`판별력(C1)` … `판별력(A2)` 줄). 픽스처를 지우거나 조건을 죽이면 그 검사가
먼저 빨개진다 — 같은 구멍이 다시 자라지 못한다.

## 돌리는 법

```
python3 scripts/tikitaka_score.py --selftest          # 이 디렉터리를 읽어 교정한다
bash    scripts/test_tikitaka_score_lanes.sh          # 회귀 앵커 + 되돌림 프로브
```

## 본측정에서 쓰는 법 (아직 안 돌렸다 — 사전등록 §6 이 미정 둘을 남겼다)

```
# ARM — 대화가 이어진다
bash scripts/sim_isolated_run.sh --arm tk --turns <turns> --reps 3 --model sonnet
# CTRL — 같은 문장, 안 이어진다 (§2-ⓒ. 🟥 이게 없으면 위 둘은 아무것도 안 잰다)
bash scripts/sim_isolated_run.sh --arm tkctrl --turns <turns> --reps 3 --model sonnet --no-resume

python3 scripts/tikitaka_score.py --transcript <out>/tk_r1.txt --spec <spec> \
        --turns <turns> --expect-resumed      # 🟥 ARM 에는 --expect-resumed 를 켠다
python3 scripts/tikitaka_score.py --transcript <out>/tkctrl_r1.txt --spec <spec> --turns <turns>
```

🟥 **이 채점기가 «못» 잡는 반증조건 둘 — 이름으로 적는다.** 채점기는 **전사본 하나**를 본다.
| | 사전등록 §4 | 왜 여기서 못 잡나 |
|---|---|---|
| **F1** | CTRL 이 ARM 과 같은 등급 | 두 **회차 사이**의 비교다. 한 전사본 안에 없다 |
| **F5** | reps 3 중 판정이 갈림(FLAKY) | 세 **회차 사이**의 비교다. 한 전사본 안에 없다 |

F2(known-pair) · F3(session_id) · F4(빈 T4)는 채점기가 기계로 잡는다(레인 L2·L5b·L5f).

🟥 **F3 이 잡는 것은 «id 가 돌아왔나» 이지 «맥락이 실려 왔나» 가 아니다.** 사전등록 §4 가
F3 를 그렇게 정의했고(«turn 2+ 가 session_id 없음»), 채점기는 그 정의에 충실하다. 다만
«턴마다 id 가 같아야 한다» 는 검사는 **일부러 안 넣었다** — 러너가 매 턴 새 id 로 갱신하므로
(`_sid="$_newsid"`) ARM 에서도 id 가 정당하게 바뀐다. 즉 **대화가 실제로 이어졌는지는
이 채널로는 미측정**이고, 그걸 재는 것은 CTRL 팔(`--no-resume`)과의 대조(F1)다.
**F1·F5 를 집행하려면 회차 묶음을 읽는 집계기가 따로 필요하다 — 아직 0줄이다.**
지금 그걸 짓지 않은 이유: 교정할 실제 회차 출력이 아직 없어서, 지으면 **미교정 계기**가 된다
(CLAUDE.md §Instrument-Calibration — known-pair 없이 숫자를 내지 않는다).
