#!/usr/bin/env bash
set -euo pipefail

# === ユーザ設定 =============================================================
GITHUB_USER="yut0takagi"           # ★あなたのGitHubユーザー名に置き換えてください
VISIBILITY="private"               # または "public"
DEFAULT_BRANCH="main"
# ============================================================================

ROOT=$(pwd)

# slugify関数：日本語や空白を小文字の英数字とハイフンに変換
slugify() {
  echo "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-'
}

# find project.json を探す（2階層まで）
find . -mindepth 2 -maxdepth 2 -name "project.json" -print0 |
while IFS= read -r -d '' JSON; do
  ORIGINAL_DIR=$(dirname "$JSON")
  cd "$ORIGINAL_DIR"

  REPO_NAME=$(jq -r '.pjt_repo_name' project.json)
  PJT_NAME=$(jq -r '.pjt_name' project.json)
  SLUG_DIR=$(slugify "$PJT_NAME")
  REMOTE_SSH="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"

  echo -e "\n=== $ORIGINAL_DIR → $REPO_NAME ==="

  # GitHubリポジトリの存在確認・作成
  if gh repo view "${GITHUB_USER}/${REPO_NAME}" &>/dev/null; then
    echo "✔️  GitHub リポジトリは既に存在"
  else
    echo "➕ GitHub に新規作成 ($REPO_NAME)"
    gh repo create "${REPO_NAME}" --${VISIBILITY} -y
  fi

  # プロジェクト側のリポジトリ初期化とpush
  if [ ! -d ".git" ]; then
    git init -b "$DEFAULT_BRANCH"
    git remote add origin "$REMOTE_SSH"
    git add .
    git commit -m "Initial commit ($REPO_NAME)"
    git push -u origin "$DEFAULT_BRANCH"
  fi

  # git-flow 初期化
  if ! git show-ref --quiet refs/heads/develop; then
    yes "" | git flow init -d
    git push -u origin develop
  fi

  cd "$ROOT"

  # 親リポジトリにサブモジュールとして追加
  if git submodule status | grep -q "${ORIGINAL_DIR}$"; then
    echo "✔️  既にサブモジュール登録済み ($ORIGINAL_DIR)"
  else
    # 通常ファイルとして既に追跡されていた場合 untrack
    if git ls-files --error-unmatch "$ORIGINAL_DIR" >/dev/null 2>&1; then
      echo "ℹ️  '$ORIGINAL_DIR' は既存トラック → untrack"
      git rm -r --cached "$ORIGINAL_DIR"
    fi

    echo "➕ サブモジュール追加 ($ORIGINAL_DIR)"
    git submodule add "$REMOTE_SSH" "$ORIGINAL_DIR"
    git commit -m "Add ${REPO_NAME} as submodule"
  fi

done