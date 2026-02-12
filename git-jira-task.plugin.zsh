# git-jira-task - Show Jira ticket title in RPROMPT
# https://github.com/gmkseta/git-jira-task

typeset -g _GIT_JIRA_PLUGIN_DIR="${0:A:h}"
typeset -g _GIT_JIRA_CONFIG_DIR="$HOME/.config/git-jira-task"

# ---------- 인터랙티브 셋업 ----------

_git_jira_setup() {
  local auto_triggered="${1:-}"

  echo ""
  echo "=== git-jira-task 초기 설정 ==="
  echo ""

  # 자동 실행 시 나중에 옵션 제공
  if [[ "$auto_triggered" == "--auto" ]]; then
    local proceed
    echo "  1) 지금 설정하기"
    echo "  2) 나중에 하기"
    echo ""
    read "proceed?선택 [1/2]: "
    if [[ "$proceed" == "2" ]]; then
      mkdir -p "$_GIT_JIRA_CONFIG_DIR"
      touch "$_GIT_JIRA_CONFIG_DIR/.skip-setup"
      echo ""
      echo "다음부터 자동 셋업이 뜨지 않습니다. 나중에 'git-jira-setup'으로 설정하세요."
      echo ""
      return
    fi
  fi

  # Jira 타입 선택
  local jira_type
  echo "Jira 타입을 선택하세요:"
  echo "  1) Jira Server / Data Center (PAT)"
  echo "  2) Jira Cloud (API Token)"
  echo ""
  read "jira_type?선택 [1/2]: "

  # Base URL
  local base_url
  echo ""
  read "base_url?Jira URL (e.g. https://jira.company.com): "
  # 끝에 / 제거
  base_url="${base_url%/}"

  local pat="" email="" api_token=""

  if [[ "$jira_type" == "2" ]]; then
    echo ""
    read "email?Jira 이메일: "
    echo ""
    read "api_token?Jira API Token: "
  else
    echo ""
    read "pat?Jira Personal Access Token: "
  fi

  # 옵션 설정
  local cache_ttl ticket_pattern prompt_color
  echo ""
  read "cache_ttl?캐시 TTL (초, 기본 3600): "
  : "${cache_ttl:=3600}"
  read "ticket_pattern?티켓 ID 패턴 (기본 [A-Z]+-[0-9]+): "
  : "${ticket_pattern:=[A-Z]+-[0-9]+}"
  read "prompt_color?프롬프트 색상 (기본 cyan): "
  : "${prompt_color:=cyan}"

  # 저장 위치 선택
  local save_location
  echo ""
  echo "설정 저장 위치:"
  echo "  1) ~/.config/git-jira-task/.env (권장)"
  echo "  2) 플러그인 디렉토리 (${_GIT_JIRA_PLUGIN_DIR}/.env)"
  echo ""
  read "save_location?선택 [1/2] (기본 1): "
  : "${save_location:=1}"

  local env_path
  if [[ "$save_location" == "2" ]]; then
    env_path="$_GIT_JIRA_PLUGIN_DIR/.env"
  else
    mkdir -p "$_GIT_JIRA_CONFIG_DIR"
    env_path="$_GIT_JIRA_CONFIG_DIR/.env"
  fi

  # .env 파일 생성
  cat > "$env_path" <<EOF
GIT_JIRA_BASE_URL=${base_url}
EOF

  if [[ "$jira_type" == "2" ]]; then
    cat >> "$env_path" <<EOF
GIT_JIRA_EMAIL=${email}
GIT_JIRA_API_TOKEN=${api_token}
EOF
  else
    cat >> "$env_path" <<EOF
GIT_JIRA_PAT=${pat}
EOF
  fi

  cat >> "$env_path" <<EOF
GIT_JIRA_CACHE_TTL=${cache_ttl}
GIT_JIRA_TICKET_PATTERN='${ticket_pattern}'
GIT_JIRA_PROMPT_COLOR=${prompt_color}
EOF

  chmod 600 "$env_path"
  # 스킵 마커 제거
  rm -f "$_GIT_JIRA_CONFIG_DIR/.skip-setup"

  echo ""
  echo "설정 저장 완료: $env_path"
  echo "셸을 다시 열거나 source ~/.zshrc 하면 적용됩니다."
  echo ""

  # 바로 로드
  _git_jira_load_env
}

# ---------- 설정 로드 ----------

_git_jira_load_env() {
  local env_file=""

  # .env 파일 탐색 순서: ~/.config → 플러그인 디렉토리
  if [[ -f "$_GIT_JIRA_CONFIG_DIR/.env" ]]; then
    env_file="$_GIT_JIRA_CONFIG_DIR/.env"
  elif [[ -f "$_GIT_JIRA_PLUGIN_DIR/.env" ]]; then
    env_file="$_GIT_JIRA_PLUGIN_DIR/.env"
  fi

  if [[ -n "$env_file" ]]; then
    local key val
    while IFS='=' read -r key val; do
      # 주석·빈줄 스킵
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue
      key="${key// /}"
      # 따옴표 제거
      val="${val%\"}"
      val="${val#\"}"
      val="${val%\'}"
      val="${val#\'}"
      # 환경변수가 이미 설정되어 있으면 우선 사용
      if [[ -z "${(P)key}" ]]; then
        export "$key=$val"
      fi
    done < "$env_file"
  fi
}

_git_jira_load_env

# 설정 없으면 자동 셋업 (스킵 마커 없을 때만)
if [[ -z "$GIT_JIRA_BASE_URL" && ! -f "$_GIT_JIRA_CONFIG_DIR/.skip-setup" ]]; then
  _git_jira_setup --auto
fi

# 사용자 명령으로 노출
alias git-jira-setup='_git_jira_setup'

# ---------- 기본값 ----------

: "${GIT_JIRA_CACHE_TTL:=3600}"
: "${GIT_JIRA_TICKET_PATTERN:=[A-Z]+-[0-9]+}"
: "${GIT_JIRA_PROMPT_COLOR:=cyan}"

typeset -g _GIT_JIRA_CACHE_DIR="$HOME/.cache/git-jira-task"
typeset -g _GIT_JIRA_LAST_TICKET=""
typeset -g _GIT_JIRA_LAST_SUMMARY=""

[[ -d "$_GIT_JIRA_CACHE_DIR" ]] || mkdir -p "$_GIT_JIRA_CACHE_DIR"

# ---------- Jira API ----------

_git_jira_fetch_summary() {
  local ticket_id="$1"
  local url="${GIT_JIRA_BASE_URL}/rest/api/2/issue/${ticket_id}?fields=summary"
  local response=""

  if [[ -n "$GIT_JIRA_EMAIL" && -n "$GIT_JIRA_API_TOKEN" ]]; then
    # Jira Cloud: Basic auth
    local cred
    cred=$(printf '%s:%s' "$GIT_JIRA_EMAIL" "$GIT_JIRA_API_TOKEN" | base64)
    response=$(curl -sf --max-time 5 \
      -H "Authorization: Basic $cred" \
      -H "Content-Type: application/json" \
      "$url" 2>/dev/null)
  elif [[ -n "$GIT_JIRA_PAT" ]]; then
    # Jira Server/DC: Bearer token
    response=$(curl -sf --max-time 5 \
      -H "Authorization: Bearer $GIT_JIRA_PAT" \
      -H "Content-Type: application/json" \
      "$url" 2>/dev/null)
  else
    return 1
  fi

  [[ -z "$response" ]] && return 1

  # JSON에서 summary 추출 (jq 의존성 없이)
  local summary
  summary=$(printf '%s' "$response" | \
    sed -n 's/.*"summary"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

  [[ -z "$summary" ]] && return 1

  printf '%s' "$summary"
}

# ---------- 캐시 ----------

_git_jira_cache_get() {
  local ticket_id="$1"
  local cache_file="$_GIT_JIRA_CACHE_DIR/$ticket_id"

  [[ ! -f "$cache_file" ]] && return 1

  # TTL 체크 (파일 수정시간 기준)
  local now file_mtime age
  now=$(date +%s)
  if [[ "$(uname)" == "Darwin" ]]; then
    file_mtime=$(stat -f %m "$cache_file" 2>/dev/null)
  else
    file_mtime=$(stat -c %Y "$cache_file" 2>/dev/null)
  fi
  [[ -z "$file_mtime" ]] && return 1

  age=$(( now - file_mtime ))
  (( age > GIT_JIRA_CACHE_TTL )) && return 1

  cat "$cache_file"
}

_git_jira_cache_set() {
  local ticket_id="$1"
  local summary="$2"
  printf '%s' "$summary" > "$_GIT_JIRA_CACHE_DIR/$ticket_id"
}

# ---------- 백그라운드 fetch ----------

_git_jira_bg_fetch() {
  local ticket_id="$1"
  local summary
  summary=$(_git_jira_fetch_summary "$ticket_id")
  if [[ -n "$summary" ]]; then
    _git_jira_cache_set "$ticket_id" "$summary"
  fi
}

# ---------- precmd 훅 ----------

_git_jira_precmd() {
  # git 디렉토리가 아니면 클리어
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    _GIT_JIRA_LAST_TICKET=""
    _GIT_JIRA_LAST_SUMMARY=""
    _git_jira_update_rprompt ""
    return
  fi

  # 설정 검증
  if [[ -z "$GIT_JIRA_BASE_URL" ]]; then
    _git_jira_update_rprompt ""
    return
  fi

  # 브랜치명에서 티켓 ID 추출
  local branch ticket_id
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -z "$branch" ]] && return

  ticket_id=$(printf '%s' "$branch" | grep -oE "$GIT_JIRA_TICKET_PATTERN" | head -1)

  # 티켓 ID 없으면 (main, develop 등) 클리어
  if [[ -z "$ticket_id" ]]; then
    _GIT_JIRA_LAST_TICKET=""
    _GIT_JIRA_LAST_SUMMARY=""
    _git_jira_update_rprompt ""
    return
  fi

  # 이전과 같은 티켓이면 이미 표시 중이므로 스킵
  if [[ "$ticket_id" == "$_GIT_JIRA_LAST_TICKET" && -n "$_GIT_JIRA_LAST_SUMMARY" ]]; then
    return
  fi

  # 캐시 확인
  local summary
  summary=$(_git_jira_cache_get "$ticket_id")

  if [[ -n "$summary" ]]; then
    _GIT_JIRA_LAST_TICKET="$ticket_id"
    _GIT_JIRA_LAST_SUMMARY="$summary"
    _git_jira_update_rprompt "$ticket_id" "$summary"
  else
    # 캐시 미스: 백그라운드로 fetch, 다음 프롬프트에 표시
    _GIT_JIRA_LAST_TICKET="$ticket_id"
    _GIT_JIRA_LAST_SUMMARY=""
    _git_jira_update_rprompt ""
    _git_jira_bg_fetch "$ticket_id" &!
  fi
}

# ---------- RPROMPT 업데이트 (non-p10k) ----------

_git_jira_update_rprompt() {
  # p10k 모드면 RPROMPT 직접 건드리지 않음
  (( _GIT_JIRA_P10K_MODE )) && return

  local ticket_id="$1"
  local summary="$2"

  # 기존 git-jira 부분 제거
  local clean_rprompt="${RPROMPT}"
  clean_rprompt="${clean_rprompt//$_GIT_JIRA_RPROMPT_SEGMENT/}"

  if [[ -n "$ticket_id" && -n "$summary" ]]; then
    _GIT_JIRA_RPROMPT_SEGMENT="%F{${GIT_JIRA_PROMPT_COLOR}}[${ticket_id}] ${summary}%f"
    RPROMPT="${_GIT_JIRA_RPROMPT_SEGMENT} ${clean_rprompt}"
    RPROMPT="${RPROMPT%% }"
    RPROMPT="${RPROMPT## }"
  else
    _GIT_JIRA_RPROMPT_SEGMENT=""
    RPROMPT="${clean_rprompt}"
    RPROMPT="${RPROMPT%% }"
    RPROMPT="${RPROMPT## }"
  fi
}

typeset -g _GIT_JIRA_RPROMPT_SEGMENT=""
typeset -gi _GIT_JIRA_P10K_MODE=0

# ---------- p10k 커스텀 세그먼트 ----------

# p10k가 호출하는 세그먼트 함수
function prompt_git_jira_task() {
  [[ -n "$_GIT_JIRA_LAST_TICKET" && -n "$_GIT_JIRA_LAST_SUMMARY" ]] || return
  p10k segment -f "${GIT_JIRA_PROMPT_COLOR}" -t "[${_GIT_JIRA_LAST_TICKET}] ${_GIT_JIRA_LAST_SUMMARY}"
}

# instant prompt 지원
function instant_prompt_git_jira_task() {
  [[ -n "$_GIT_JIRA_LAST_TICKET" && -n "$_GIT_JIRA_LAST_SUMMARY" ]] || return
  p10k segment -f "${GIT_JIRA_PROMPT_COLOR}" -t "[${_GIT_JIRA_LAST_TICKET}] ${_GIT_JIRA_LAST_SUMMARY}"
}

# p10k 자동 등록 (첫 precmd 시점에 실행)
typeset -gi _GIT_JIRA_P10K_REGISTERED=0

_git_jira_register_p10k() {
  (( _GIT_JIRA_P10K_REGISTERED )) && return
  _GIT_JIRA_P10K_REGISTERED=1

  # p10k가 로드되었는지 확인
  [[ -n "$POWERLEVEL9K_LEFT_PROMPT_ELEMENTS" ]] || return

  _GIT_JIRA_P10K_MODE=1

  # 이미 등록되어 있으면 스킵
  (( ${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[(Ie)git_jira_task]} )) && return

  # vcs 바로 뒤에 삽입, vcs 없으면 끝에 추가
  local idx=${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[(i)vcs]}
  if (( idx <= ${#POWERLEVEL9K_LEFT_PROMPT_ELEMENTS} )); then
    POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
      "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[@]:0:$idx}"
      git_jira_task
      "${POWERLEVEL9K_LEFT_PROMPT_ELEMENTS[@]:$idx}"
    )
  else
    POWERLEVEL9K_LEFT_PROMPT_ELEMENTS+=(git_jira_task)
  fi

  # p10k에 변경 반영
  (( ${+functions[p10k]} )) && p10k reload 2>/dev/null
}

# ---------- 훅 등록 ----------

_git_jira_init_precmd() {
  _git_jira_register_p10k
  _git_jira_precmd
}

# 중복 등록 방지
if (( ! ${+precmd_functions[(r)_git_jira_init_precmd]} )); then
  precmd_functions+=(_git_jira_init_precmd)
fi
