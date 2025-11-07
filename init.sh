#!/bin/bash
cd ../

if [[ ! -f ".gclient" ]]; then
  echo "首次生成 .gclient（直接 heredoc 写入，包含关闭 v8）"
  cat > .gclient <<'EOF'
solutions = [
  { "name"        : 'pdfium',
    "url"         : 'https://pdfium.googlesource.com/pdfium.git',
    "deps_file"   : 'DEPS',
    "managed"     : False,
    "custom_deps" : {
    },
    "custom_vars": {
      "checkout_v8": False,
    },
  },
]
EOF

  # 用实际变量值替换占位符（避免在上面 heredoc 中被 shell 展开）
  sed -i "s|ORIGIN_URL_PLACEHOLDER|${ORIGIN_URL}|g" .gclient
else
  echo ".gclient 已存在，若要关闭 v8 请确认包含 checkout_v8=False 或 custom_deps 过滤。"
  echo $PWD
fi
