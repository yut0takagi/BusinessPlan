#!/usr/bin/env bash
set -euo pipefail

# === ユーザ設定 =============================================================
GITHUB_USER="yut0takagi"
VISIBILITY="public"              # public / private
DEFAULT_BRANCH="main"             # main / master
# ============================================================================

ROOT=$(pwd)

find . -mindepth 2 -maxdepth 2 -name "project.json" -print0 |
while IFS= read -r -d '' JSON; do
  DIR=$(dirname "$JSON")
  cd "$DIR"

  # --- 1) project.json からメタを取得 --------------------------------------
  REPO_NAME=$(jq -r '.pjt_repo_name' project.json)
  REMOTE_SSH="git@github.com:${GITHUB_USER}/${REPO_NAME}.git"

  echo -e "\n=== ${DIR}  →  ${REPO_NAME} ==="

  # --- 2) リモートが無いなら GitHub に新規作成 ------------------------------
  if gh repo view "${GITHUB_USER}/${REPO_NAME}" &>/dev/null; then
    echo "✔️  GitHub リポジトリは既に存在"
  else
    if [ -z "$REPO_NAME" ] || [ "$REPO_NAME" == "null" ]; then
      echo "❌ project.json に pjt_repo_name がありません"; exit 1
    fi
    echo "➕ GitHub に新規作成 (${REPO_NAME})"
    gh repo create "${REPO_NAME}" --${VISIBILITY} -y
  fi

  # --- 3) ローカルが git 管理でなければ初期化 ------------------------------
  if [ ! -d ".git" ]; then
    git init -b "${DEFAULT_BRANCH}"
    git remote add origin "${REMOTE_SSH}"
    git add .
    git commit -m "Initial commit (${REPO_NAME})"
    git push -u origin "${DEFAULT_BRANCH}"
  fi

  # --- 4) git-flow 初期化（既に develop があればスキップ） ----------------
  if ! git show-ref --quiet refs/heads/develop; then
    git flow init -d                                   # すべて既定値
    git push -u origin main
  fi

  cd "$ROOT"

  @@
   # --- 5) 親リポジトリにサブモジュール登録 -------------------------------
   if git submodule status | grep -q "${DIR}$"; then
     echo "✔️  既にサブモジュール登録済み"

   else
  +  # もし普通のディレクトリとしてトラッキングされていたら index から外す
  +  if git ls-files --error-unmatch "${DIR}" >/dev/null 2>&1; then
  +    echo "ℹ️  '${DIR}' は既存トラック → untrack して置き換え"
  +    git rm -r --cached "${DIR}"
  +  fi
  +
     echo "➕ サブモジュール追加"
     git submodule add "${REMOTE_SSH}" "${DIR}"
     git commit -m "Add ${REPO_NAME} as submodule"
   fi
done