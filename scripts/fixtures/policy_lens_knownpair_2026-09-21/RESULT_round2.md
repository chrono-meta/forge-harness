# RESULT — 정책 렌즈 다리 ⓒ 2차 측정 · 2026-09-24

봉인: `PREREG_round2.md` sha256 `29a528394388a790242634c8c0803860636b06d7c238ffd5d615e506cf6935d7`
(측정 전 봉인 · 측정 후 `shasum -c` OK · 봉인문 미수정). 정답키 `KEY_round2.tsv` sha256
`a4b7233691b271334cb909a5840f404110f74f3963d9548c32126aa1ccb45a81` (런 시작 전 해시).
채점기 `score_policy_lens.sh` sha256 `ad742ffb…ae956` — 봉인문 §고정 해시와 일치(채점 직전 재확인).

## 판정 — F1 · F2 · F3 **어느 것도 발동하지 않았다.** 🟥 단 F3 는 넓힌 키 위에서만 선다(아래 §하중선).

```
                     HIGH(주)          HIGH∪MED(부)      GROUNDED    ONTARGET
ARM  positive        6/6  (A1 3 · B1 3)   6/6                6/6          6/6
ARM  negative        0/6                  0/6                6/6          NA
CTRL positive        0/6                  0/6                3/6 †        NO-CORPUS
CTRL negative        0/6                  5/6 (A2 3 · B2 2)  6/6          NO-CORPUS
```
- **F1 바닥**: A1 3/3 · B1 3/3 flagged (바 = 3 중 2) → **미발동.**
- **F2 판별**: 6/6 − 0/6 = **1.0 > 0** → **미발동.**
- **F3 정책 읽기**: GROUNDED 6/6 (NOQUOTE 0 — 분모 규칙상 실패로 셀 런 없음) · ONTARGET 6/6 → **미발동.**
- **해석표 1행**: ARM positive flagged · CTRL positive 미flagged → «정책 코퍼스가 유효 성분».
  축 B(유지주체 불일치, 본문만으로 안 보이게 설계) 에서도 ARM 3/3 vs CTRL 0/3 — «강한 부정 신호» 아님.
- 유효 24/24 (INVALID 0 · PARTIAL 칸 0). 오염 grep 0/24. 🟥 CTRL 방향은 1차와 같다 — 정책 없는 팔은
  «기본값 off · opt-in» positive 를 LOW 로, 겉보기만 무서운 negative 를 MEDIUM 으로 찍었다.

† **CTRL-A1 PHANTOM 3/3 은 채점기 아티팩트다 — 손검증.** 인용 `This is off by default. Without
--web, not one byte …` 은 PR 11행에 **실재**한다. 원문이 `**This is off by default.** Without …`
(마크다운 굵게)라 `**` 가 부분문자열 대조를 깬다. 1차의 «줄바꿈» 과 **같은 부류**(채점기가 PHANTOM 을
제조) 이고 이번엔 다른 표기다. F1–F3 은 ARM 전용이라 **판정에 영향 없음.** 채점기는 봉인에 해시로
묶여 있어 **이 결과 안에서 고치지 않는다** → 후속으로 연다(§열린 것).

## 🟥 하중선 — F3 의 초록은 «넓힌 키» 에 기대고 있다

같은 2차 런을 **v1 키의 문장만으로** 채점하면(진단 — 판정 아님, 토큰 게이트만 끔):
```
ARM-A1_POS r1–r3   OFFTARGET ×3   ← 세 런 모두 «We do not run as a background daemon and we do not listen on a socket.» 을 인용
ARM-B1_POS r1–r3   ONTARGET  ×3
⇒ v1 키였다면 ONTARGET 3/6 < 2/3 → F3 발동
```
그 소켓 문장은 VOID 문서가 **1차 결과를 보고** «키에서 빠졌다» 고 적은 바로 그 문장이다. 그래서 이
초록의 무게는 전부 «그 문장을 키에 넣은 절차가 결과-튜닝이 아니었나» 에 실린다. 근거와 한계를 둘 다 적는다:

- **근거**: 봉인문 §변경 3 이 키 규칙(주석 CORE∪BORDERLINE ∪ v1)을 **주석이 돌아오기 전에** 고정했고,
  주석자 #2 는 그 문장을 **CORE** 로 달았다(«PR adds an HTTP listener on 127.0.0.1, i.e. listens on a
  socket»). PR 이 실제로 소켓을 연다 — 문장이 이 PR 을 지배한다는 것은 독립 독자에게 자명했다.
- 🟥 **한계 ① 독립 증인은 하나다.** 주석자 #1 도 같은 문장을 CORE 로 달았지만 #1 은 오염돼 있다(아래).
- 🟥 **한계 ② 저자는 이 문장이 빠진 것을 알고 있었다**(봉인문 §저자는 블라인드가 아니다). 규칙이
  주석자 판단에 전부를 넘긴 이유가 그것이고, 이 세션은 키에 문장을 **더하지도 빼지도 않았다**
  (드롭 0 — 주석의 모든 문장이 정책 파일에 축자 실재).

⇒ 인용할 때의 정직한 형태: **«독립 주석으로 지배 문장을 전수한 키에서 F3 미발동; v1 의 두-문장 키로는
A1 이 전부 과녁 밖»**. 한쪽만 인용하지 마라.

## 계기 결함 — 이번 회차에서 난 것, 이름으로

| # | 결함 | 언제 잡혔나 | 처분 |
|---|---|---|---|
| ⑧ | **주석자 #1 에 라벨 누설** — 사본 파일명이 `*_A1_POS_PR.md` 그대로 | 주석자 본인이 보고 | #1 **실격**, 중립 파일명(`PR_q/m/z/k`)으로 #2 재실행. 누설 스캔 known-positive = 정책의 합법 낱말 «accept» 히트 → 계기 생존, 라벨 히트 0 |
| ⑨ | **#1 주석 파일 mtime 이 봉인문보다 71초 앞선다**(19:16:46 < 19:17:57) | 봉인 직전 mtime 대조 | 봉인문 작성 중 #1 내용을 안 봤다는 근거는 **전사본 순서뿐**, 기계 증거 없음 → ⑧ 과 함께 #1 실격 사유. #2 는 봉인(19:18) **뒤** 발주(19:18:25) |
| ⑩ | CTRL 인용이 마크다운 `**` 에 걸려 PHANTOM | 결과 후 손검증 | 판정 무영향(ARM 전용 F). 채점기 후속 수리 |
| ⑪ | 전제 기록의 `rc=` 가 빈칸 — zsh 에 `PIPESTATUS` 없음 | 기록 직후 육안 | `out=$(cmd); rc=$?` 로 재실행, rc=0 · rc=0 기록(`round2_preconditions.log`) |

⑧ 매핑(주석 파일명 → 픽스처): `tidewatch/PR_m`=A1 · `PR_q`=A2 · `ferrule/PR_z`=B1 · `PR_k`=B2.
주석 #2 결과: A1 CORE 3 + BORDERLINE 2 · A2 CORE 0 (BORDERLINE 2) · B1 CORE 5 + BORDERLINE 5 · B2 NONE.
봉인 규칙 3 적용: negative 에 CORE 0 → **네 픽스처 전부 실행.** A2 의 BORDERLINE 둘은 키에 넣지 않았다 —
정답 ACCEPT 픽스처는 `ontarget=NA` 이고 F1–F3 어디에도 들어가지 않으므로 판정 무영향(여기 명시).

## 실행 기록

- 전제: `ablation_calibrate.sh` rc=0 («all controls held») · `score_policy_lens.sh --selftest` rc=0 — 런 전 같은 기록.
- `run_arms.sh <scratch> 3` 무수정 · 8 칸 전부 `rc=0 files=15` · 24/24 캡처 · 러너 판정 `RESULT: CLEAN`.
- 블라인드 제거: 러너는 `BLIND-STRIP FAILED` 시 `continue 2` 로 **캡처 전에** 회차를 버린다 → 24/24
  캡처 = 24/24 제거 성공. 추가로 픽스처는 런 시점 **미커밋**이라 HEAD 클론에 애초에 없다.
- `runs_round2/` = 응답 24 · 자료 8 · 프롬프트 8 · `SCORES.tsv`. 제자리 재채점이 `SCORES.tsv` 와 바이트 동일.

## 결과 «뒤» 채점기 수정 — 판정 무영향을 실행으로 확인

cross-family(codex/gpt-5.5) R1 이 채점기에서 fail-open 하나를 찾았고(빈 `unique_token` 칸이 게이트를
끈다), 재현하다 **더 깊은 원인**이 나왔다: `IFS=$'\t' read` 에서 탭은 IFS **공백**이라 연속 탭이 접혀
빈 칸이 사라지고 뒤 칸이 전부 왼쪽으로 밀린다. 둘 다 고쳤다(레인 P8, fail-before 실측 · 되돌림 적색).
그래서 지금 채점기 해시는 봉인문 §고정 해시와 **다르다.** 🟥 판정 무영향 증거:
`runs_round1 → SCORES.tsv` 바이트 동일(P2) · `runs_round2 → SCORES.tsv` 바이트 동일(제자리 재채점).
두 KEY 모두 빈 칸이 없어 수정 경로를 안 지난다 — 그 사실이 «동일» 의 이유이지 우연이 아니다.

## 이 결과가 주장하지 않는 것

- **렌즈를 «지어도 된다» 까지만 말한다** — 반증 조건이 셋 다 미발동이라는 것. 실제 메인테이너 예측력 ·
  정책이 암묵적인 실레포로의 일반화 · `standpoint: tier3` 자격 — 전부 봉인문이 미리 배제했다.
- **6/6 · 0/6 은 픽스처 4개 위의 수치다.** 픽스처가 «명시된 정책 · 한 단계 추론» 으로 지어졌으니
  천장 효과일 수 있다 — 쉬운 과녁에서의 만점은 변별력의 상한을 말하지 않는다.
- reps = 3 은 바의 최소치다.

## 열린 것

1. 채점기 ⑩ — 대조 전에 마크다운 강조(`**`·`__`·`` ` ``)를 양쪽에서 벗긴다. known-pair: 굵게 된 원문의
   진짜 인용 → GROUNDED · 지어낸 인용 → PHANTOM, 같은 회차. 🟥 **1차 SCORES.tsv 재현(P2) 이 바이트 동일로
   남는지** 먼저 보라 — 바뀌면 VOID 문서의 수치가 조용히 다른 뜻이 된다.
2. 픽스처가 쉬운가 — 정책이 «두 단계 추론» 을 요구하는 known-positive 한 쌍을 더해 천장을 잰다.
