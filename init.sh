if [[ ! -f ".gclient" ]]; then
  log "首次生成 .gclient（直接 heredoc 写入，包含关闭 v8）"
  cat > .gclient <<'EOF'
solutions = [
  {
    "url": ORIGIN_URL_PLACEHOLDER,
    "managed": False,
    "name": "src",
    "custom_vars": {
      "checkout_v8": False,
    },
    "custom_deps": {
      "v8": None,
      "third_party/v8": None,
    },
  },
]
target_os = []
EOF

  # 用实际变量值替换占位符（避免在上面 heredoc 中被 shell 展开）
  sed -i "s|ORIGIN_URL_PLACEHOLDER|${ORIGIN_URL}|g" .gclient
else
  log ".gclient 已存在，若要关闭 v8 请确认包含 checkout_v8=False 或 custom_deps 过滤。"
fi
