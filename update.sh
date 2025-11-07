set -euo pipefail

# ---------------------------
# 默认参数 & 解析
# ---------------------------
BASE_BRANCH="${SYNC_BASE_BRANCH:-quickprint-main}"
UPSTREAM_REMOTE="${SYNC_UPSTREAM_REMOTE:-upstream}"
UPSTREAM_URL="${SYNC_UPSTREAM_URL:-https://pdfium.googlesource.com/pdfium.git}"
ORIGIN_REMOTE="${SYNC_ORIGIN_REMOTE:-origin}"
AUTO_CREATE_PR="${SYNC_PR_AUTO_CREATE:-true}"
PUSH_ON_CONFLICT="${SYNC_PUSH_ON_CONFLICT:-true}"
TAG_ON_SUCCESS="${SYNC_TAG_ON_SUCCESS:-true}"
BRANCH_ARG=""
SKIP_MERGE="false"



cd pdfium

if ! git remote get-url "$UPSTREAM_REMOTE" &>/dev/null; then
  echo "添加 upstream 远端：$UPSTREAM_URL"
  git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi


echo "[INFO] Fetch upstream..."
git fetch "$UPSTREAM_REMOTE" main --depth=200 || git fetch "$UPSTREAM_REMOTE" main

echo "[INFO] Fetch origin base branch..."
git fetch "$ORIGIN_REMOTE" "$BASE_BRANCH" --depth=200 || git fetch "$ORIGIN_REMOTE" "$BASE_BRANCH"



# ---------------------------
# 生成/确定分支名
# ---------------------------
if [[ -z "$BRANCH_ARG" ]]; then
  TS=$(date +'%Y%m%d-%H%M')
  SYNC_BRANCH="sync-upstream-$TS"
else
  SYNC_BRANCH="$BRANCH_ARG"
fi

echo "[INFO] 同步分支: $SYNC_BRANCH"
echo "[INFO] 基线分支: $BASE_BRANCH"


# ---------------------------
# 创建或重置同步分支
# ---------------------------
if git show-ref --verify --quiet "refs/heads/$SYNC_BRANCH"; then
  echo "[INFO] 本地已有分支 $SYNC_BRANCH，切换。"
  git checkout "$SYNC_BRANCH"
else
  echo "[INFO] 基于 $BASE_BRANCH 创建分支 $SYNC_BRANCH"
  git checkout -b "$SYNC_BRANCH" "$ORIGIN_REMOTE/$BASE_BRANCH"
fi

UPSTREAM_SHA=$(git rev-parse "$UPSTREAM_REMOTE/main")
BASE_SHA=$(git rev-parse HEAD)
echo "[INFO] Upstream SHA: $UPSTREAM_SHA"
echo "[INFO] Base HEAD SHA: $BASE_SHA"

MERGE_STATUS="skipped"

if [[ "$SKIP_MERGE" == "false" ]]; then
  echo "[INFO] 尝试 merge upstream/main 到 $SYNC_BRANCH ..."
  set +e
  git merge --no-ff --no-edit "$UPSTREAM_REMOTE/main"
  EC=$?
  set -e

  if [[ $EC -ne 0 ]]; then
    MERGE_STATUS="conflict"
    echo "[WARN] 合并发生冲突。"
  else
    MERGE_STATUS="clean"
    echo "[INFO] 合并成功，无冲突。"
  fi
else
  echo "[INFO] 跳过 merge（人工已处理后再次运行场景）。"
  MERGE_STATUS="post-resolution"
fi

# ---------------------------
# 冲突检测与文件列表
# ---------------------------
CONFLICT_FILES=""
if [[ "$MERGE_STATUS" == "conflict" ]]; then
  # 列出未解决冲突文件
  CONFLICT_FILES=$(git diff --name-only --diff-filter=U || true)
  echo "[INFO] 冲突文件列表："
  echo "$CONFLICT_FILES" | sed 's/^/  - /'

  
  echo "[INFO] 冲突状态下不推送分支，脚本正常退出（exit 0）。"
  echo "请人工解决冲突后重新运行："
  echo "  1) 编辑全部冲突文件并删除 <<<<<<< ======= >>>>>>> 标记"
  echo "  2) git add . && git commit -m \"Resolve conflicts\""
  echo "  3) 再次运行脚本（可加 --skip-merge 或保留原逻辑）"

  exit 0
fi




     echo "[INFO] 推送分支到远端: $SYNC_BRANCH"
  git push "$ORIGIN_REMOTE" "$SYNC_BRANCH"
