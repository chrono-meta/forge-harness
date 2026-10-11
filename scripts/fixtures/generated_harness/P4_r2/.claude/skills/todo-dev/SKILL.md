---
name: todo-dev
description: TODO CLI(todo/cli.py)에 명령을 추가하거나 버그를 고치고 테스트를 작성하는 방법. todo 앱 코드 수정·기능 추가·테스트 작성·리팩터링 작업에 사용한다. 수정, 보완, 다시 구현 요청에도 사용한다.
---

# TODO CLI 개발 방법

## 구조
- `todo/cli.py`: `load`/`save`(JSON 파일, 경로는 `TODO_DB` 환경변수, 기본 `todo.json`), 명령 함수, `main(argv)`.
- `tests/test_cli.py`: pytest 테스트. 현재는 자리표시자뿐이다.

## 절차
1. 변경 전 `python -m pytest`로 현재 상태를 확인한다.
2. 새 명령은 함수로 분리하고 `main`에 분기를 추가한다. 기존 명령의 출력 형식은 사용자 스크립트가 의존할 수 있으니 유지한다.
3. 테스트는 `tmp_path`와 `monkeypatch.setenv("TODO_DB", ...)`로 격리한다. `DB`는 import 시점에 읽히므로 `cli.DB`를 monkeypatch하는 편이 확실하다.
4. 입력 오류(인자 없음, 범위 밖 번호, 숫자 아님)는 트레이스백 대신 안내 메시지와 0이 아닌 종료 코드로 처리한다. 현재 코드는 이를 처리하지 않으므로, 건드리는 명령에서 함께 보강한다.
5. 끝나면 `python -m pytest`를 다시 실행하고 결과를 보고서에 적는다.

이유: 이 코드는 매우 얇아서 회귀를 잡아 줄 것이 테스트뿐이다. 그래서 변경마다 테스트를 같이 둔다.
