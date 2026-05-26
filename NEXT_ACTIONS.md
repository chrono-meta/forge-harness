# forge-harness — Next Actions (akaa1941 session)

> 이 파일은 akaa1941 CC 세션이 읽을 용도입니다. 순서대로 실행하세요.

## Step 1 — GitHub 컨택: harness-evolver

URL: https://github.com/raphaelchristi/harness-evolver/issues/new

**제목**: Independent architectural convergence with forge-harness

**내용**:
```
Hi — I'm the author of forge-harness
(https://github.com/chrono-code/forge-harness), a Claude Code
harness engineering toolkit.

While cross-auditing your project (our PR #4), we confirmed that
forge-harness and harness-evolver independently converged on the
same outer-loop architecture:
field observation → adversarial critique → synthesis → integration → verification

We're preparing an arXiv paper on harness engineering methods and
would love to cite harness-evolver as a related work demonstrating
independent convergence. Would you be open to mutual citation?

Paper draft (Zenodo DOI pending — will update)
Cross-audit PR: https://github.com/chrono-code/forge-harness/pull/4
```

---

## Step 2 — GitHub 컨택: Sylph.AI

arXiv 2604.21003 저자 이메일 또는 해당 GitHub repo Issues.

**제목**: Related work + independent convergence — forge-harness

**내용**:
```
Hi — We cite "The Last Harness You'll Ever Build" (arXiv:2604.21003)
in our paper on harness engineering methods.

forge-harness (https://github.com/chrono-code/forge-harness)
independently converged on a self-evolution loop similar to your
architecture. Would you be open to mutual citation in related work?

Paper draft (Zenodo DOI pending — will update)
```

---

## Step 3 — Zenodo 업로드 (DOI 발급)

1. https://zenodo.org/uploads/new 열기
2. 파일 업로드: `paper/arxiv_paper_v0.5.pdf` (이 레포에 있음)
   - GitHub에서 직접 다운로드:
     https://github.com/chrono-code/forge-harness/blob/main/paper/arxiv_paper_v0.5.pdf
3. 메타데이터:
   - **Title**: forge-harness: Engineering Methods for Robust AI Collaboration Harnesses
   - **Type**: Technical Report
   - **Keywords**: harness engineering, adversarial validation, phantom detection, self-evolution, Claude Code
4. Publish → DOI 발급
5. 발급된 DOI를 Step 1/2 이슈 댓글에 추가

---

## Step 4 — arXiv 제출

1. https://submit.arxiv.org 열기
2. **Category**: cs.SE (primary), cs.AI (cross-list)
3. 파일: `paper/arxiv_paper_v0.5.pdf`
4. Zenodo DOI 먼저 확보 후 진행

---

## Step 5 — 레포 공개 전환 (준비됐을 때)

1. https://github.com/chrono-code/forge-harness/settings
   → Danger Zone → Make public
2. **즉시** branch protection 설정:

```bash
gh api repos/chrono-code/forge-harness/branches/main/protection \
  -X PUT -H "Accept: application/vnd.github+json" \
  --input - << 'JSON'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 1,
    "dismiss_stale_reviews": false
  },
  "restrictions": null
}
JSON
```

   → 이후 외부 사용자는 반드시 PR로만 기여 가능.

---

## 참고

- 논문 파일: `paper/arxiv_paper_v0.5.pdf` (이 레포)
- 독립 수렴 근거: PR #4 (harness-evolver cross-audit)
- 관련 arXiv 논문: 2603.28052, 2604.14228, 2604.21003, 2605.18747
