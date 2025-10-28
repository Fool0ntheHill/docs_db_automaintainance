#!/bin/bash
# 多知识库批量同步脚本 (Linux/Mac)
# 使用方法：将此文件复制到项目根目录并运行

echo "开始多知识库同步..."
echo

# 检查配置文件是否存在
if [ ! -f ".env.main" ]; then
    echo "错误：.env.main 配置文件不存在"
    echo "请先复制 test/.env.main.example 为 .env.main 并修改配置"
    exit 1
fi

if [ ! -f ".env.test" ]; then
    echo "错误：.env.test 配置文件不存在"
    echo "请先复制 test/.env.test.example 为 .env.test 并修改配置"
    exit 1
fi

# 同步到主知识库
echo "========================================"
echo "同步到主知识库..."
echo "========================================"
cp .env.main .env
python tke_dify_sync.py
if [ $? -ne 0 ]; then
    echo "主知识库同步失败！"
    exit 1
fi

echo
echo "========================================"
echo "同步到测试知识库..."
echo "========================================"
cp .env.test .env
python tke_dify_sync.py
if [ $? -ne 0 ]; then
    echo "测试知识库同步失败！"
    exit 1
fi

echo
echo "========================================"
echo "多知识库同步完成！"
echo "========================================"
echo "主知识库：已同步"
echo "测试知识库：已同步"
echo
echo "查看日志文件："
echo "  - tke_sync_main.log"
echo "  - tke_sync_test.log"
echo