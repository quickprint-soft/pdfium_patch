#!/usr/bin/env bash
set -euo pipefail

# ================= 配置区域 =================
UPSTREAM_URL="https://pdfium.googlesource.com/pdfium.git"
UP_BRANCH="main"
WORK_ROOT="/c/Users/Administrator/tmp"
REPO_DIR="${WORK_ROOT}/pdfium"
ORIGIN_URL="git@quick-print:quickprint-soft/pdfium.git"

PATCH_BRANCH="quickprint-main"
RUN_BUILD=true            # 如果不需要构建改为 false
GN_ARGS="is_debug=true pdf_enable_v8=false pdf_enable_xfa=false pdf_enable_xfa_javascript=false"
# =================================================

log() { echo "[`date +'%Y-%m-%d %H:%M:%S'`] $*"; }

log "进入工作根目录: ${WORK_ROOT}"
mkdir -p "${WORK_ROOT}"
cd "${WORK_ROOT}"

# 1. 生成 .gclient （首次）
if [[ ! -f ".gclient" ]]; then
  log "首次执行 gclient config"
  gclient config --unmanaged "${ORIGIN_URL}"
  log "准备在 .gclient 中插入 checkout_v8=False 或 custom_deps 过滤 v8"
  python - <<'PY'
import re, os, io
path=".gclient"
text=open(path,"r",encoding="utf-8").read()

# 若已有 custom_vars 则补充，否则插入
if "custom_vars" in text:
    # 简单粗暴：若没写 checkout_v8，插入到 custom_vars 花括号里
    if "checkout_v8" not in text:
        text=re.sub(r'custom_vars\s*:\s*\{', "custom_vars: { 'checkout_v8': False,", text, 1)
else:
    # 在 managed False 后面插入 custom_vars
    text=re.sub(r"'managed'\s*:\s*False\s*,?",
                "'managed': False,\n    'custom_vars': { 'checkout_v8': False },",
                text, 1)

# 兜底：加 custom_deps 过滤 v8（如果后面发现 checkout_v8 不生效可以手动调整）
if "custom_deps" not in text:
    text=re.sub(r"'managed'\s*:\s*False.*?\n",
                lambda m: m.group(0)+"    'custom_deps': { 'v8': None, 'third_party/v8': None },\n",
                text, 1, flags=re.DOTALL)

open(path,"w",encoding="utf-8").write(text)
PY
else
  log ".gclient 已存在，若要关闭 v8 请确认包含 checkout_v8=False 或 custom_deps 映射"
fi

# 2. 同步（此时按修改后的 .gclient 拉取：应跳过 v8）
log "执行 gclient sync（期望不下载 v8）"
gclient sync

# 3. 进入主仓库
log "进入仓库目录: ${REPO_DIR}"
cd "${REPO_DIR}"

# 4. 添加 upstream
if git remote get-url upstream &>/dev/null; then
  log "upstream 已存在: $(git remote get-url upstream)"
else
  log "添加 upstream -> ${UPSTREAM_URL}"
  git remote add upstream "${UPSTREAM_URL}"
fi

# 5. 拉取上游 main
log "fetch upstream/${UP_BRANCH}"
git fetch upstream "${UP_BRANCH}"

# 6. 更新本地 main（merge 保留历史；如需镜像改为 reset）
log "切换到 main"
git checkout main
log "合并 upstream/${UP_BRANCH} → main"
if git merge --no-edit upstream/"${UP_BRANCH}"; then
  log "main 已吸收最新 upstream/${UP_BRANCH}"
else
  log "main 合并冲突，请手动解决再重新运行脚本从推送 main 步开始"
  exit 1
fi

# 7. 同步依赖（DEPS 可能更新）
log "回到工作根目录执行二次 gclient sync（应用最新 DEPS，不含 v8）"
cd "${WORK_ROOT}"
gclient sync
cd "${REPO_DIR}"

# 8. 推送 main
log "推送 main 到 origin"
git push origin main || log "main 推送失败，检查权限或网络"
log "main 同步完成"

# 9. 验证是否没有 v8 目录
log "检查 v8 目录是否存在"
[[ -d v8 ]] && log "[警告] 仍存在 ./v8 目录，说明过滤可能未生效"
[[ -d third_party/v8 ]] && log "[警告] 仍存在 ./third_party/v8 目录，说明过滤可能未生效"
[[ ! -d v8 && ! -d third_party/v8 ]] && log "已过滤 v8 源码目录（未发现 v8 / third_party/v8）"

# 10. 处理补丁分支
log "处理补丁分支 ${PATCH_BRANCH}"
if git rev-parse --verify "${PATCH_BRANCH}" &>/dev/null; then
  git checkout "${PATCH_BRANCH}"
  log "已切换到补丁分支"
else
  if git ls-remote --exit-code origin "refs/heads/${PATCH_BRANCH}" &>/dev/null; then
    log "远端有 ${PATCH_BRANCH}，创建跟踪分支"
    git checkout -b "${PATCH_BRANCH}" "origin/${PATCH_BRANCH}"
  else
    log "远端无 ${PATCH_BRANCH}，从 main 新建"
    git checkout -b "${PATCH_BRANCH}" main
    git push origin "${PATCH_BRANCH}"
  fi
fi

# 11. 合并 main 到补丁分支
log "合并 main → ${PATCH_BRANCH}"
if git merge --no-edit main; then
  log "补丁分支已吸收 main"
else
  log "补丁分支合并冲突，解决后重新运行脚本剩余部分"
  exit 1
fi

## 12. （补丁分支若未改 DEPS，一般不再需要 gclient sync；如你私有改动修改了 DEPS，可再执行一次）
#log "补丁分支未声明修改 DEPS，跳过二次 gclient sync（需要时手动执行）"
#
## 13. 可选构建（无 v8）
#if ${RUN_BUILD}; then
#  if command -v gn &>/dev/null && command -v ninja &>/dev/null; then
#    log "生成 NoV8 构建: gn gen out/NoV8 --args='${GN_ARGS}'"
#    gn gen out/NoV8 --args="${GN_ARGS}" || { log "GN 失败，检查参数或过滤是否生效"; exit 1; }
#    log "开始编译（目标 pdfium）"
#    ninja -C out/NoV8 pdfium || { log "编译失败，检查日志"; exit 1; }
#    log "NoV8 构建完成"
#  else
#    log "未找到 gn 或 ninja，跳过构建"
#  fi
#else
#  log "RUN_BUILD=false，跳过构建"
#fi

# 14. 推送补丁分支
log "推送补丁分支 ${PATCH_BRANCH}"
git push origin "${PATCH_BRANCH}" || log "补丁分支推送失败，检查权限或网络"

log "全部完成：main & ${PATCH_BRANCH} 同步（过滤 v8）结束"
