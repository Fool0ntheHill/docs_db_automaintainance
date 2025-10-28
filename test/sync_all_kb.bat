@echo off
REM 多知识库批量同步脚本 (Windows)
REM 使用方法：将此文件复制到项目根目录并运行

echo 开始多知识库同步...
echo.

REM 检查配置文件是否存在
if not exist ".env.main" (
    echo 错误：.env.main 配置文件不存在
    echo 请先复制 test\.env.main.example 为 .env.main 并修改配置
    pause
    exit /b 1
)

if not exist ".env.test" (
    echo 错误：.env.test 配置文件不存在
    echo 请先复制 test\.env.test.example 为 .env.test 并修改配置
    pause
    exit /b 1
)

REM 同步到主知识库
echo ========================================
echo 同步到主知识库...
echo ========================================
copy .env.main .env >nul
python tke_dify_sync.py
if errorlevel 1 (
    echo 主知识库同步失败！
    pause
    exit /b 1
)

echo.
echo ========================================
echo 同步到测试知识库...
echo ========================================
copy .env.test .env >nul
python tke_dify_sync.py
if errorlevel 1 (
    echo 测试知识库同步失败！
    pause
    exit /b 1
)

echo.
echo ========================================
echo 多知识库同步完成！
echo ========================================
echo 主知识库：已同步
echo 测试知识库：已同步
echo.
echo 查看日志文件：
echo   - tke_sync_main.log
echo   - tke_sync_test.log
echo.
pause