# git-jira-task 개발 가이드

## 프로젝트 개요
Git 브랜치명에서 Jira 티켓 ID를 추출하여 프롬프트에 티켓 제목을 표시하는 zsh 플러그인.

## 구조
```
git-jira-task.plugin.zsh  # 메인 플러그인 (전체 로직)
.env.example               # 설정 예시
README.md                  # 설치/사용법
```

## 핵심 동작 흐름
1. 셸 시작 → `.env` 로드 → 설정 없으면 `_git_jira_setup --auto` 실행
2. `precmd` 훅 → 브랜치에서 티켓 ID 추출 → 캐시 확인
3. 캐시 히트 → 즉시 표시 / 캐시 미스 → 백그라운드 fetch → 다음 프롬프트에 표시
4. p10k 감지 시 → LEFT_PROMPT_ELEMENTS의 `vcs` 뒤에 커스텀 세그먼트 자동 등록
5. p10k 없으면 → RPROMPT에 직접 표시

## 환경변수 (모두 `GIT_JIRA_` 프리픽스)
- `GIT_JIRA_BASE_URL` - Jira 서버 URL
- `GIT_JIRA_PAT` - Server/DC용 Personal Access Token
- `GIT_JIRA_EMAIL` / `GIT_JIRA_API_TOKEN` - Cloud용
- `GIT_JIRA_CACHE_TTL` - 캐시 TTL (기본 3600초)
- `GIT_JIRA_TICKET_PATTERN` - 티켓 ID 정규식 (기본 `[A-Z]+-[0-9]+`)
- `GIT_JIRA_PROMPT_COLOR` - 표시 색상 (기본 cyan)
- `GIT_JIRA_BRANCH_PREFIX` - gjc 브랜치 접두사 (기본 `feature/`)
- `GIT_JIRA_BASE_BRANCH` - gjc 새 브랜치 기준 브랜치 (기본 `develop`)

## 설정 파일 위치 (우선순위)
1. 환경변수 (이미 설정된 경우)
2. `~/.config/git-jira-task/.env`
3. 플러그인 디렉토리의 `.env`

## 캐시
- 위치: `~/.cache/git-jira-task/`
- 파일명: 티켓 ID (예: `QUICK-904`)
- 내용: 티켓 제목 텍스트
- TTL: 파일 수정시간 기준, macOS `stat -f %m` / Linux `stat -c %Y`

## p10k 연동
- `prompt_git_jira_task()` / `instant_prompt_git_jira_task()` 함수 정의
- 첫 precmd 시점에 p10k 감지 → `POWERLEVEL9K_LEFT_PROMPT_ELEMENTS`에 자동 삽입
- `_GIT_JIRA_P10K_MODE=1`이면 RPROMPT 직접 조작 안 함

## 테스트 방법
```bash
# p10k 없이 순수 zsh에서 테스트
zsh -f
source ~/.oh-my-zsh/custom/plugins/git-jira-task/git-jira-task.plugin.zsh
cd <git-repo-with-jira-branch>
# 엔터 → RPROMPT 확인

# API 직접 테스트
curl -s -H "Authorization: Bearer $GIT_JIRA_PAT" \
  "${GIT_JIRA_BASE_URL}/rest/api/2/issue/QUICK-904?fields=summary"
```

## 배포
- GitHub: gmkseta/git-jira-task
- 변경 후 push → 사용자는 플러그인 디렉토리에서 `git pull`
- `.env`는 `.gitignore`에 포함, 커밋 금지

## gjc 동작 흐름
1. `gjc` 실행 → git repo 확인 → Jira 설정 확인
2. `_git_jira_search_issues()` → JQL `assignee=currentUser() AND statusCategory!=Done` 조회
3. `_git_jira_parse_issues()` → JSON에서 key/summary/status 추출 (jq 없이 grep+sed)
4. `_git_jira_select_ticket()` → fzf 선택 UI (없으면 zsh select fallback)
5. `_git_jira_do_checkout()` → 로컬/리모트/신규 브랜치 분기 체크아웃

## gjc 관련 함수
- `_git_jira_curl()` - 인증 분기 공통 curl wrapper (`_git_jira_fetch_summary`도 사용)
- `_git_jira_url_encode()` - JQL URL 인코딩 (pure zsh, RFC 3986)
- `_git_jira_search_issues()` - `/rest/api/2/search` 호출
- `_git_jira_parse_issues()` - JSON → key/summary/status 배열 추출
- `_git_jira_select_ticket()` - fzf 선택 (fallback: zsh select)
- `_git_jira_do_checkout()` - 브랜치 존재 여부 판단 후 checkout/create
- `_git_jira_checkout()` - gjc 메인 오케스트레이터

## 주의사항
- `precmd_functions` 빈 배열일 때 math expression 에러 주의 → `${+precmd_functions[(r)...]}` 사용
- p10k는 플러그인보다 나중에 로드됨 → 감지는 반드시 precmd 시점에
- Jira Server PAT(`MTYy...`)과 Cloud PAT(`ATATT3x...`)은 인증 방식이 다름
