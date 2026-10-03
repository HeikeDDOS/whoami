#!/usr/bin/env zsh

# ==========================================
#  .zshrc 备份脚本 - 永久安装版
# ==========================================

# --- 安装路径配置 ---
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly SCRIPT_NAME="zshrc-backup"
readonly SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
readonly DESKTOP_LINK="${HOME}/Desktop/${SCRIPT_NAME}.command"
readonly LAUNCH_AGENT="${HOME}/Library/LaunchAgents/com.user.zshrc-backup.plist"

# --- 颜色定义 ---
autoload -U colors && colors

local FG_MAIN="\033[38;5;81m"
local FG_SUCCESS="\033[38;5;85m"
local FG_WARN="\033[38;5;215m"
local FG_ERROR="\033[38;5;203m"
local FG_INFO="\033[38;5;111m"
local FG_MUTED="\033[38;5;245m"
local RESET="\033[0m"
local BOLD="\033[1m"

local ICON_SUCCESS="✅"
local ICON_ERROR="❌"
local ICON_WARN="⚠️"
local ICON_INFO="📌"
local ICON_INSTALL="📦"
local ICON_UNINSTALL="🗑️"

# --- 辅助函数 ---
print_header() {
    clear
    echo "\n${BOLD}${FG_MAIN}══════════════════════════════════════════${RESET}"
    echo "${BOLD}${FG_MAIN}  $1${RESET}"
    echo "${BOLD}${FG_MAIN}══════════════════════════════════════════${RESET}\n"
}

print_success() { echo "${ICON_SUCCESS} ${FG_SUCCESS}$1${RESET}" }
print_error()   { echo "${ICON_ERROR} ${FG_ERROR}$1${RESET}" }
print_warn()    { echo "${ICON_WARN} ${FG_WARN}$1${RESET}" }
print_info()    { echo "${ICON_INFO} ${FG_INFO}$1${RESET}" }

pause() {
    echo "\n${FG_MUTED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -n "${FG_INFO}按任意键继续...${RESET}"
    read -k1
    echo ""
}

# ==========================================
#  核心备份功能（与之前相同）
# ==========================================

export ZSHRC_BACKUP_DIR="${HOME}/.zshrc_backups"
export MAX_BACKUPS=10

init_backup_dir() {
    if [[ ! -d "$ZSHRC_BACKUP_DIR" ]]; then
        mkdir -p "$ZSHRC_BACKUP_DIR"
        print_success "创建备份目录: $ZSHRC_BACKUP_DIR"
    fi
}

get_backup_list() {
    local backups=($(ls -1t "$ZSHRC_BACKUP_DIR"/.zshrc_backup_*.sh 2>/dev/null))
    echo "${backups[@]}"
}

cleanup_old_backups() {
    local backups=($(get_backup_list))
    local backup_count=${#backups[@]}
    
    if [[ $backup_count -gt $MAX_BACKUPS ]]; then
        print_info "清理旧备份..."
        for ((i=$MAX_BACKUPS; i<$backup_count; i++)); do
            rm -f "${backups[$i+1]}"
            echo "  🗑️  删除: $(basename "${backups[$i+1]}")"
        done
    fi
}

create_backup() {
    print_header "${ICON_INFO} 备份 .zshrc"
    
    if [[ ! -f ~/.zshrc ]]; then
        print_error "未找到 ~/.zshrc 文件"
        print_info "是否创建新的 .zshrc 文件？(y/N)"
        read -k1 create_new
        echo ""
        if [[ "$create_new" == "y" || "$create_new" == "Y" ]]; then
            touch ~/.zshrc
            print_success "已创建 ~/.zshrc"
        else
            pause
            return 1
        fi
    fi
    
    init_backup_dir
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${ZSHRC_BACKUP_DIR}/.zshrc_backup_${timestamp}.sh"
    
    echo -n "${FG_INFO}正在备份...${RESET}"
    
    if cp ~/.zshrc "$backup_file" 2>/dev/null; then
        echo "\r${ICON_SUCCESS} ${FG_SUCCESS}备份成功！${RESET}  "
        local file_size=$(du -h "$backup_file" | cut -f1)
        echo "\n${FG_MUTED}备份信息:${RESET}"
        echo "  📦 文件: $(basename "$backup_file")"
        echo "  📏 大小: $file_size"
        echo "  📅 时间: $(date '+%Y-%m-%d %H:%M:%S')"
        
        cleanup_old_backups
    else
        echo "\r${ICON_ERROR} ${FG_ERROR}备份失败！${RESET}  "
        pause
        return 1
    fi
    
    pause
}

list_backups() {
    print_header "${ICON_INFO} 备份列表"
    
    local backups=($(get_backup_list))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        print_warn "暂无备份文件"
        pause
        return 1
    fi
    
    echo "${FG_MUTED}┌────┬──────────────────────────────────────────┬──────────┐${RESET}"
    echo "${FG_MUTED}│ ${BOLD}序号${RESET}${FG_MUTED} │ ${BOLD}文件名${RESET}${FG_MUTED}                                    │ ${BOLD}大小${RESET}${FG_MUTED}    │${RESET}"
    echo "${FG_MUTED}├────┼──────────────────────────────────────────┼──────────┤${RESET}"
    
    local idx=1
    for backup in $backups; do
        local basename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        printf "${FG_MUTED}│${RESET} ${FG_MAIN}%2d${RESET} ${FG_MUTED}│${RESET} %-40s ${FG_MUTED}│${RESET} %6s ${FG_MUTED}│${RESET}\n" \
            $idx "$basename" "$size"
        ((idx++))
    done
    
    echo "${FG_MUTED}└────┴──────────────────────────────────────────┴──────────┘${RESET}"
    echo "\n${FG_MUTED}总计: ${#backups[@]} 个备份 (保留最近 ${MAX_BACKUPS} 个)${RESET}"
    
    pause
}

restore_backup() {
    print_header "${ICON_INFO} 恢复备份"
    
    local backups=($(get_backup_list))
    
    if [[ ${#backups[@]} -eq 0 ]]; then
        print_error "没有可用的备份文件"
        pause
        return 1
    fi
    
    echo "${FG_MUTED}可用的备份:${RESET}\n"
    local idx=1
    for backup in $backups; do
        local basename=$(basename "$backup")
        local date_str=$(echo "$basename" | grep -o '[0-9]\{8\}_[0-9]\{6\}')
        local pretty_date=$(echo "$date_str" | sed 's/\(....\)\(..\)\(..\)_\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')
        echo "  ${FG_MAIN}[$idx]${RESET} ${basename} ${FG_MUTED}(${pretty_date})${RESET}"
        ((idx++))
    done
    
    echo "\n${FG_INFO}请选择要恢复的备份 [1-${#backups[@]}]，或按 0 取消:${RESET}"
    echo -n "${BOLD}➜ ${RESET}"
    read choice
    
    if [[ "$choice" == "0" ]]; then
        print_info "操作已取消"
        pause
        return 0
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#backups[@]} ]]; then
        print_error "无效的选择"
        pause
        return 1
    fi
    
    local selected_backup="${backups[$choice]}"
    
    echo "\n${FG_WARN}⚠️  警告：此操作将覆盖当前的 ~/.zshrc${RESET}"
    echo -n "${FG_WARN}确认恢复？(y/N) ${RESET}"
    read -k1 confirm
    echo ""
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "操作已取消"
        pause
        return 0
    fi
    
    local auto_backup="${ZSHRC_BACKUP_DIR}/.zshrc_auto_$(date +%Y%m%d_%H%M%S).sh"
    cp ~/.zshrc "$auto_backup" 2>/dev/null
    
    if cp "$selected_backup" ~/.zshrc; then
        print_success "恢复成功！"
        echo "\n${FG_INFO}💡 提示：运行以下命令使更改生效${RESET}"
        echo "  ${FG_MAIN}source ~/.zshrc${RESET}"
    else
        print_error "恢复失败"
    fi
    
    pause
}

clean_all() {
    print_header "${ICON_INFO} 清理备份"
    
    local backups=($(get_backup_list))
    if [[ ${#backups[@]} -eq 0 ]]; then
        print_warn "没有需要清理的备份"
        pause
        return 0
    fi
    
    echo "${FG_WARN}⚠️  警告：将删除所有 ${#backups[@]} 个备份文件${RESET}"
    echo -n "${FG_WARN}确认清理？(y/N) ${RESET}"
    read -k1 confirm
    echo ""
    
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        rm -rf "$ZSHRC_BACKUP_DIR"
        print_success "已清理所有备份"
    else
        print_info "操作已取消"
    fi
    
    pause
}

show_menu() {
    print_header "🎯 .zshrc 备份管理工具"
    
    echo "${BOLD}请选择操作:${RESET}\n"
    echo "  ${FG_MAIN}1${RESET}) 💾 备份 .zshrc"
    echo "  ${FG_MAIN}2${RESET}) 📋 查看备份列表"
    echo "  ${FG_MAIN}3${RESET}) 🔄 恢复备份"
    echo "  ${FG_MAIN}4${RESET}) 🧹 清理所有备份"
    echo "  ${FG_MAIN}0${RESET}) 退出"
    echo ""
    echo -n "${BOLD}➜ ${RESET}"
    read -k1 choice
    echo ""
    
    case $choice in
        1) create_backup ;;
        2) list_backups ;;
        3) restore_backup ;;
        4) clean_all ;;
        0) 
            echo "\n${FG_INFO}再见！${RESET}"
            exit 0
            ;;
        *)
            print_error "无效选择"
            sleep 1
            show_menu
            ;;
    esac
}

# ==========================================
#  安装/卸载功能
# ==========================================

# 创建桌面快捷方式
create_desktop_link() {
    cat > "$DESKTOP_LINK" << EOF
#!/usr/bin/env zsh
# 桌面快捷方式 - 双击运行 .zshrc 备份工具
exec "$SCRIPT_PATH"
EOF
    chmod +x "$DESKTOP_LINK"
    print_success "已创建桌面快捷方式: $DESKTOP_LINK"
}

# 安装到系统
install() {
    print_header "${ICON_INSTALL} 安装 .zshrc 备份工具"
    
    # 创建安装目录
    mkdir -p "$INSTALL_DIR"
    
    # 复制脚本
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    print_success "已安装到: $SCRIPT_PATH"
    
    # 创建桌面链接
    create_desktop_link
    
    # 添加到 PATH（如果不存在）
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo "\n# 添加用户本地二进制路径" >> ~/.zshrc
        echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.zshrc
        print_success "已添加 $INSTALL_DIR 到 PATH"
    fi
    
    # 创建别名
    if ! grep -q "alias zbackup=" ~/.zshrc 2>/dev/null; then
        cat >> ~/.zshrc << 'EOF'

# .zshrc 备份别名
alias zbackup='zshrc-backup'
alias zbackup-list='zshrc-backup --list'
alias zbackup-restore='zshrc-backup --restore'
EOF
        print_success "已添加命令行别名"
    fi
    
    print_success "\n✨ 安装完成！"
    echo "\n${FG_INFO}使用方法:${RESET}"
    echo "  • 双击桌面图标: ${FG_MAIN}${SCRIPT_NAME}.command${RESET}"
    echo "  • 终端运行: ${FG_MAIN}zbackup${RESET}"
    echo "  • 终端运行: ${FG_MAIN}zshrc-backup${RESET}"
    
    pause
}

# 设置自动备份（每小时）
setup_auto_backup() {
    print_header "🤖 设置自动备份"
    
    # 创建 launchd 配置文件
    cat > "$LAUNCH_AGENT" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.zshrc-backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_PATH</string>
        <string>--auto-backup</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/.zshrc_backups/auto_backup.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.zshrc_backups/auto_backup_error.log</string>
</dict>
</plist>
EOF
    
    # 加载服务
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null
    launchctl load "$LAUNCH_AGENT"
    
    print_success "已设置自动备份（每小时）"
    pause
}

# 卸载
uninstall() {
    print_header "${ICON_UNINSTALL} 卸载 .zshrc 备份工具"
    
    echo "${FG_WARN}⚠️  此操作将删除所有备份文件和配置${RESET}"
    echo -n "${FG_WARN}确认卸载？(y/N) ${RESET}"
    read -k1 confirm
    echo ""
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "已取消卸载"
        pause
        return 0
    fi
    
    # 停止自动备份
    launchctl unload "$LAUNCH_AGENT" 2>/dev/null
    rm -f "$LAUNCH_AGENT"
    
    # 删除脚本和快捷方式
    rm -f "$SCRIPT_PATH"
    rm -f "$DESKTOP_LINK"
    
    # 删除备份目录
    rm -rf "$ZSHRC_BACKUP_DIR"
    
    # 从 .zshrc 中移除别名（可选）
    echo -n "${FG_INFO}是否从 .zshrc 中移除别名？(y/N) ${RESET}"
    read -k1 remove_alias
    echo ""
    if [[ "$remove_alias" == "y" || "$remove_alias" == "Y" ]]; then
        sed -i '' '/# .zshrc 备份别名/d' ~/.zshrc 2>/dev/null
        sed -i '' '/alias zbackup/d' ~/.zshrc 2>/dev/null
        print_success "已移除别名"
    fi
    
    print_success "卸载完成"
    pause
}

# 自动备份模式（用于定时任务）
auto_backup_mode() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${ZSHRC_BACKUP_DIR}/.zshrc_backup_${timestamp}.sh"
    
    mkdir -p "$ZSHRC_BACKUP_DIR"
    
    if cp ~/.zshrc "$backup_file" 2>/dev/null; then
        # 清理旧备份
        local backups=($(ls -1t "$ZSHRC_BACKUP_DIR"/.zshrc_backup_*.sh 2>/dev/null))
        local backup_count=${#backups[@]}
        
        if [[ $backup_count -gt $MAX_BACKUPS ]]; then
            for ((i=$MAX_BACKUPS; i<$backup_count; i++)); do
                rm -f "${backups[$i+1]}"
            done
        fi
        echo "[$(date)] 自动备份成功: $backup_file"
    else
        echo "[$(date)] 自动备份失败"
    fi
}

# ==========================================
#  主程序
# ==========================================

main() {
    # 解析命令行参数
    case "${1:-}" in
        --install)
            install
            ;;
        --uninstall)
            uninstall
            ;;
        --auto-backup)
            auto_backup_mode
            ;;
        --setup-auto)
            setup_auto_backup
            ;;
        --help|-h)
            cat << EOF
.zshrc 备份工具 - 永久安装版

用法: $0 [选项]

选项:
    --install      安装到系统并创建桌面快捷方式
    --uninstall    卸载并删除所有备份
    --setup-auto   设置自动备份（每小时）
    --auto-backup  自动备份模式（用于定时任务）
    --help, -h     显示此帮助信息

无需参数时启动交互式备份管理工具

示例:
    $0 --install     # 安装到系统
    $0 --setup-auto  # 开启自动备份
    $0               # 启动交互式菜单
EOF
            ;;
        *)
            # 检查是否已安装，未安装则提示
            if [[ ! -f "$SCRIPT_PATH" ]] && [[ "$0" != "$SCRIPT_PATH" ]]; then
                print_warn "检测到首次运行"
                echo "\n${FG_INFO}是否安装到系统？(y/N)${RESET}"
                echo -n "${BOLD}➜ ${RESET}"
                read -k1 install_choice
                echo ""
                if [[ "$install_choice" == "y" || "$install_choice" == "Y" ]]; then
                    install
                fi
            fi
            # 运行交互式菜单
            while true; do
                show_menu
            done
            ;;
    esac
}

# 运行主程序
main "$@"
