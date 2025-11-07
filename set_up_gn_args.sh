#!/bin/bash

# 检查是否提供了参数
if [ -z "$1" ]; then
    echo "Usage: $0 <platform>"
    exit 1
fi

# 获取传入的参数
platform=$1

cd ../pdfium
# 创建输出目录
mkdir -p out/${platform}

# 创建 args.gn 文件并写入配置
cat << EOF > out/${platform}/args.gn
use_goma=false
clang_use_chrome_plugins=false
pdf_is_standalone=true
pdf_use_skia=false
pdf_use_skia_paths=false
is_component_build=false
pdf_is_complete_lib=true
pdf_enable_xfa=false
pdf_enable_v8=false
target_cpu="x64"
is_clang=true
use_custom_libcxx=false         # 关键：禁用 libc++，改用 MSVC STL
EOF

# 根据平台设置调试选项
if [ "${platform}" == "x64_dbg_md_no_v8" ]; then
    echo "is_debug=true" >> out/${platform}/args.gn
    echo "enable_iterator_debugging=false" >> out/${platform}/args.gn
    echo "pdf_use_partition_alloc=false" >> out/${platform}/args.gn
    echo "use_allocator_shim=false" >> out/${platform}/args.gn
else
    echo "is_debug=false" >> out/${platform}/args.gn
    echo "pdf_use_partition_alloc=false" >> out/${platform}/args.gn
    echo "use_allocator_shim=false" >> out/${platform}/args.gn
fi

# 输出配置文件内容
cat out/${platform}/args.gn
