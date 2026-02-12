# git-jira-task

Git 브랜치명에서 Jira 티켓 ID를 추출하여 zsh 프롬프트 오른쪽(RPROMPT)에 티켓 제목을 표시하는 플러그인.

```
~/project (feature/QUICK-123) $                    [QUICK-123: 로그인 기능 구현]
```

## 특징

- 어떤 프롬프트 프레임워크(p10k, oh-my-zsh, starship, 순수 zsh)와도 호환
- Jira Server/DC (PAT) 및 Jira Cloud (API Token) 지원
- 파일 기반 캐싱으로 API 호출 최소화
- 캐시 미스 시 백그라운드 fetch → 다음 프롬프트에 표시 (프롬프트 지연 없음)
- 기존 RPROMPT 보존

## 설치

### zinit

```zsh
zinit light gmkseta/git-jira-task
```

### antigen

```zsh
antigen bundle gmkseta/git-jira-task
```

### oh-my-zsh

```bash
git clone https://github.com/gmkseta/git-jira-task.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/git-jira-task
```

`~/.zshrc`에서 플러그인 추가:

```zsh
plugins=(... git-jira-task)
```

### 수동 설치

```bash
git clone https://github.com/gmkseta/git-jira-task.git ~/.zsh/git-jira-task
```

`~/.zshrc`에 추가:

```zsh
source ~/.zsh/git-jira-task/git-jira-task.plugin.zsh
```

## 설정

### 방법 1: 인터랙티브 셋업 (권장)

설치 후 처음 셸을 열면 안내 메시지가 표시됩니다:

```
[git-jira-task] 설정이 없습니다. 'git-jira-setup' 명령으로 초기 설정을 진행하세요.
```

```bash
git-jira-setup
```

Jira 타입, URL, 인증 정보를 순서대로 입력하면 `~/.config/git-jira-task/.env`에 자동 저장됩니다.
설정을 변경하려면 `git-jira-setup`을 다시 실행하면 됩니다.

### 방법 2: 환경변수

`~/.zshrc`에 직접 설정 (환경변수가 .env 파일보다 우선):

```zsh
export GIT_JIRA_BASE_URL=https://jira.your-company.com
export GIT_JIRA_PAT=your-personal-access-token
```

### 설정 항목

| 변수 | 필수 | 설명 | 기본값 |
|------|:----:|------|--------|
| `GIT_JIRA_BASE_URL` | O | Jira 서버 URL | - |
| `GIT_JIRA_PAT` | △ | Jira Server/DC Personal Access Token | - |
| `GIT_JIRA_EMAIL` | △ | Jira Cloud 이메일 | - |
| `GIT_JIRA_API_TOKEN` | △ | Jira Cloud API 토큰 | - |
| `GIT_JIRA_CACHE_TTL` | | 캐시 유지 시간(초) | `3600` |
| `GIT_JIRA_TICKET_PATTERN` | | 티켓 ID 정규식 | `[A-Z]+-[0-9]+` |
| `GIT_JIRA_PROMPT_COLOR` | | 표시 색상 | `cyan` |
| `GIT_JIRA_BRANCH_PREFIX` | | `gjc` 브랜치 접두사 | `feature/` |
| `GIT_JIRA_BASE_BRANCH` | | `gjc` 새 브랜치 기준 브랜치 | `develop` |

> △ = Jira Server/DC면 `GIT_JIRA_PAT`, Jira Cloud면 `GIT_JIRA_EMAIL` + `GIT_JIRA_API_TOKEN` 필요

### 인증 설정

**Jira Server/DC** — Personal Access Token 사용:

1. Jira → 프로필 → Personal Access Tokens → Create token
2. `.env`에 `GIT_JIRA_PAT` 설정

> [Jira PAT 발급 가이드](https://confluence.atlassian.com/enterprise/using-personal-access-tokens-1026032365.html)

**Jira Cloud** — API Token 사용:

1. https://id.atlassian.com/manage-profile/security/api-tokens 에서 토큰 생성
2. `.env`에 `GIT_JIRA_EMAIL`과 `GIT_JIRA_API_TOKEN` 설정

> [Jira Cloud API Token 가이드](https://support.atlassian.com/atlassian-account/docs/manage-api-tokens-for-your-atlassian-account/)

## 지원 브랜치 형식

- `feature/QUICK-123`
- `bugfix/QUICK-456-some-description`
- `QUICK-789`
- `hotfix/PROJ-42-fix-login`

`GIT_JIRA_TICKET_PATTERN`을 변경하여 커스텀 패턴도 지원 가능.

## `gjc` - Jira 티켓 브랜치 체크아웃

`gjc` 명령으로 Jira에서 자신에게 할당된 열린 티켓을 조회하고, 선택한 티켓의 브랜치를 체크아웃합니다.

```bash
gjc
```

**동작 흐름:**

1. Jira API로 `assignee = currentUser() AND statusCategory != Done` 티켓 조회
2. fzf로 티켓 선택 (fzf 없으면 번호 선택 fallback)
3. 브랜치 체크아웃:
   - 로컬에 `feature/PROJ-123` 있으면 → `git checkout`
   - 리모트에 있으면 → `git checkout --track`
   - 없으면 → `origin/develop`에서 새 브랜치 생성

브랜치 접두사와 기준 브랜치는 `GIT_JIRA_BRANCH_PREFIX`, `GIT_JIRA_BASE_BRANCH`로 변경 가능.

## 캐시

캐시 파일은 `~/.cache/git-jira-task/`에 저장됩니다.

```bash
# 캐시 초기화
rm -rf ~/.cache/git-jira-task/*
```

## 라이선스

MIT
