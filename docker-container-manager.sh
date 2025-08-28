#!/bin/bash

##
#    Advanced Docker Container Manager (dcon)
#    Version 2.0.0
#
#    A comprehensive Docker container management tool with an intuitive interface 
#    featuring shell access, log viewing, stats monitoring, port mappings, 
#    favorites, and much more.
#
#    Features:
#    - Interactive shell access with automatic shell detection
#    - Live and static log viewing with timestamps
#    - Real-time container stats monitoring
#    - Container information and port mappings
#    - Favorites system and command history
#    - Dynamic responsive tables
#    - Partial name matching and multiple actions
#
#    Documentation: https://github.com/disisto/docker-container-manager
#    Installation: sudo mv docker-container-manager.sh /usr/local/bin/dcon
#
#    Licensed under MIT (https://github.com/disisto/docker-container-manager/blob/main/LICENSE)
#
#    Copyright (c) 2023-2025 Roberto Di Sisto
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.
##

set -euo pipefail  # Strict error handling

# Configuration - Use HOME directory for portability across different script locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.docker-selector"
FAVORITES_FILE="$CONFIG_DIR/favorites"
HISTORY_FILE="$CONFIG_DIR/history"
CONFIG_FILE="$CONFIG_DIR/config"

# Default configuration
DEFAULT_LOG_LINES=50
DEFAULT_THEME="light"

# Colors for themes
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Set theme colors
case "${THEME:-$DEFAULT_THEME}" in
    "dark")
        COLOR_HEADER="\033[1;36m"    # Cyan
        COLOR_SUCCESS="\033[1;32m"   # Green
        COLOR_ERROR="\033[1;31m"     # Red
        COLOR_WARNING="\033[1;33m"   # Yellow
        COLOR_INFO="\033[1;34m"      # Blue
        COLOR_RESET="\033[0m"
        ;;
    *)
        COLOR_HEADER="\033[1;34m"    # Blue
        COLOR_SUCCESS="\033[1;32m"   # Green
        COLOR_ERROR="\033[1;31m"     # Red
        COLOR_WARNING="\033[1;33m"   # Yellow
        COLOR_INFO="\033[0;36m"      # Cyan
        COLOR_RESET="\033[0m"
        ;;
esac

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Function to print colored text
print_color() {
    local color="$1"
    local text="$2"
    echo -e "${color}${text}${COLOR_RESET}"
}

# Function to check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        print_color "$COLOR_ERROR" "Error: Docker is not running or not accessible"
        exit 1
    fi
}

# Function to get running containers
get_containers() {
    docker ps --format "{{.Names}}" 2>/dev/null || {
        print_color "$COLOR_ERROR" "Error: Failed to get container list"
        exit 1
    }
}

# Function to get container detailed info
get_container_details() {
    local container="$1"
    local info
    
    # Get comprehensive container information
    info=$(docker inspect "$container" --format '
IP: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}
Image: {{.Config.Image}}
Status: {{.State.Status}}
Uptime: {{.State.StartedAt}}
Ports: {{range .NetworkSettings.Ports}}{{.}}{{end}}
Memory: {{.HostConfig.Memory}}
' 2>/dev/null)
    
    echo "$info"
}

# Function to get container IP address
get_container_ip() {
    local container="$1"
    local ip
    
    # Try to get IP from default bridge network first
    ip=$(docker inspect "$container" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null | head -n1)
    
    # If no IP found, try to get from any network
    if [ -z "$ip" ] || [ "$ip" = "<no value>" ]; then
        ip=$(docker inspect "$container" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{if $conf.IPAddress}}{{$conf.IPAddress}}{{end}}{{end}}' 2>/dev/null | head -n1)
    fi
    
    # Fallback
    [ -z "$ip" ] || [ "$ip" = "<no value>" ] && ip="N/A"
    echo "$ip"
}

# Function to get container uptime
get_container_uptime() {
    local container="$1"
    local started
    
    started=$(docker inspect "$container" --format '{{.State.StartedAt}}' 2>/dev/null)
    if [ -n "$started" ] && [ "$started" != "<no value>" ]; then
        # Calculate uptime (simplified)
        local start_epoch current_epoch uptime_seconds
        start_epoch=$(date -d "$started" +%s 2>/dev/null || echo "0")
        current_epoch=$(date +%s)
        uptime_seconds=$((current_epoch - start_epoch))
        
        if [ $uptime_seconds -gt 86400 ]; then
            echo "$((uptime_seconds / 86400))d"
        elif [ $uptime_seconds -gt 3600 ]; then
            echo "$((uptime_seconds / 3600))h"
        elif [ $uptime_seconds -gt 60 ]; then
            echo "$((uptime_seconds / 60))m"
        else
            echo "${uptime_seconds}s"
        fi
    else
        echo "N/A"
    fi
}

# Function to get container ports in readable format
get_container_ports() {
    local container="$1"
    local ports
    
    # Get port mappings in a more readable format
    ports=$(docker port "$container" 2>/dev/null | sed 's/0\.0\.0\.0:/*/g' | sed 's/:::/*:/g' | tr '\n' ', ' | sed 's/, $//')
    
    # If no port mappings, check for exposed ports
    if [ -z "$ports" ]; then
        local exposed_ports
        exposed_ports=$(docker inspect "$container" --format '{{range $port, $conf := .Config.ExposedPorts}}{{$port}} {{end}}' 2>/dev/null | tr ' ' ',' | sed 's/,$//')
        
        if [ -n "$exposed_ports" ] && [ "$exposed_ports" != " " ]; then
            ports="($exposed_ports)"
        else
            ports="N/A"
        fi
    fi
    
    echo "$ports"
}

# Function to format ports for display (shortened version)
format_ports_for_display() {
    local ports="$1"
    local max_width="$2"
    
    # Don't format if we're calculating width (max_width > 100)
    if [ "$max_width" -gt 100 ]; then
        # Replace common patterns for shorter display (for width calculation)
        ports=$(echo "$ports" | sed 's/443\/tcp -> \*/443→*/g')
        ports=$(echo "$ports" | sed 's/80\/tcp -> \*/80→*/g')
        ports=$(echo "$ports" | sed 's/8080\/tcp -> \*/8080→*/g')
        ports=$(echo "$ports" | sed 's/\/tcp -> \*/→*/g')
        ports=$(echo "$ports" | sed 's/\/udp -> \*/→*[UDP]/g')
        echo "$ports"
        return
    fi
    
    # Replace common patterns for shorter display
    ports=$(echo "$ports" | sed 's/443\/tcp -> \*/443→*/g')
    ports=$(echo "$ports" | sed 's/80\/tcp -> \*/80→*/g')
    ports=$(echo "$ports" | sed 's/8080\/tcp -> \*/8080→*/g')
    ports=$(echo "$ports" | sed 's/\/tcp -> \*/→*/g')
    ports=$(echo "$ports" | sed 's/\/udp -> \*/→*[UDP]/g')
    
    # Truncate if still too long
    if [ ${#ports} -gt $max_width ]; then
        # Try to truncate smartly - keep the first few ports
        if [[ "$ports" == *","* ]]; then
            # Multiple ports - show first one and indicate more
            first_port=$(echo "$ports" | cut -d',' -f1)
            if [ ${#first_port} -le $((max_width - 4)) ]; then
                ports="${first_port},..."
            else
                ports="${ports:0:$((max_width-3))}..."
            fi
        else
            # Single port - just truncate
            ports="${ports:0:$((max_width-3))}..."
        fi
    fi
    
    echo "$ports"
}

# Function to check if container is in favorites
is_favorite() {
    local container="$1"
    [ -f "$FAVORITES_FILE" ] && grep -q "^$container$" "$FAVORITES_FILE"
}

# Function to add to favorites
add_favorite() {
    local container="$1"
    if ! is_favorite "$container"; then
        echo "$container" >> "$FAVORITES_FILE"
        print_color "$COLOR_SUCCESS" "Added '$container' to favorites"
    else
        print_color "$COLOR_WARNING" "'$container' is already in favorites"
    fi
}

# Function to remove from favorites
remove_favorite() {
    local container="$1"
    if [ -f "$FAVORITES_FILE" ]; then
        grep -v "^$container$" "$FAVORITES_FILE" > "$FAVORITES_FILE.tmp" && mv "$FAVORITES_FILE.tmp" "$FAVORITES_FILE"
        print_color "$COLOR_SUCCESS" "Removed '$container' from favorites"
    fi
}

# Function to add to history
add_to_history() {
    local container="$1"
    local action="$2"
    
    # Keep last 20 entries
    {
        echo "$(date '+%Y-%m-%d %H:%M:%S')|$container|$action"
        [ -f "$HISTORY_FILE" ] && head -n 19 "$HISTORY_FILE"
    } > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
}

# Function to display help under table
show_table_help() {
    echo "Quick commands:"
    echo "  [1-9] | [name]    Select container    |  'd' Toggle detailed view    |  'f' Show favorites"
    echo "  'h' Show history  |  'q' Quit          |  Partial names supported (e.g., 'web' matches 'web-server')"
    echo
}

# Function to calculate column widths dynamically
calculate_column_widths() {
    local containers=("$@")
    local show_detailed="${DETAILED_VIEW:-false}"
    
    # Minimum widths
    local min_nr=3
    local min_name=15
    local min_ip=10
    local min_uptime=6
    local min_ports=5
    local min_fav=1
    
    # Calculate maximum widths needed
    local max_name=0
    local max_ip=0
    local max_uptime=0
    local max_ports=0
    
    # Find longest container name
    for container in "${containers[@]}"; do
        if [ ${#container} -gt $max_name ]; then
            max_name=${#container}
        fi
    done
    
    if [ "$show_detailed" = "true" ]; then
        # Find longest IP address
        for container in "${containers[@]}"; do
            local ip=$(get_container_ip "$container")
            if [ ${#ip} -gt $max_ip ]; then
                max_ip=${#ip}
            fi
        done
        
        # Calculate uptime and ports widths for detailed view
        for container in "${containers[@]}"; do
            local uptime=$(get_container_uptime "$container")
            local ports=$(get_container_ports "$container")
            
            # Format ports for width calculation
            ports=$(format_ports_for_display "$ports" 999) # No limit for width calculation
            
            if [ ${#uptime} -gt $max_uptime ]; then
                max_uptime=${#uptime}
            fi
            
            if [ ${#ports} -gt $max_ports ]; then
                max_ports=${#ports}
            fi
        done
        
        if [ $max_ports -gt 50 ]; then
            max_ports=50
        fi
    fi
    
    # Apply minimum widths but respect maximums for readability
    WIDTH_NR=$min_nr
    WIDTH_NAME=$(( max_name > min_name ? (max_name < 50 ? max_name : 50) : min_name ))
    
    if [ "$show_detailed" = "true" ]; then
        WIDTH_IP=$(( max_ip > min_ip ? max_ip : min_ip ))
        WIDTH_UPTIME=$(( max_uptime > min_uptime ? max_uptime : min_uptime ))
        WIDTH_PORTS=$(( max_ports > min_ports ? max_ports : min_ports ))
    fi
    
    WIDTH_FAV=$min_fav
    
    # Export for use in display function
    export WIDTH_NR WIDTH_NAME WIDTH_IP WIDTH_UPTIME WIDTH_PORTS WIDTH_FAV
}

# Function to display container list with dynamic columns
display_containers() {
    local containers=("$@")
    local show_detailed="${DETAILED_VIEW:-false}"
    
    # Calculate optimal column widths
    calculate_column_widths "${containers[@]}"
    
    print_color "$COLOR_HEADER" "Running containers:"
    echo
    
    if [ "$show_detailed" = "true" ]; then
        # Advanced view with IP, uptime, ports, favorites
        printf "+$(printf '%*s' $((WIDTH_NR + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_NAME + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_IP + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_UPTIME + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_PORTS + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_FAV + 2)) | tr ' ' '-')+\n"
        
        printf "| %-*s | %-*s | %-*s | %-*s | %-*s | %-*s |\n" \
            $WIDTH_NR "Nr." \
            $WIDTH_NAME "Container Name" \
            $WIDTH_IP "IP Address" \
            $WIDTH_UPTIME "Uptime" \
            $WIDTH_PORTS "Ports" \
            $WIDTH_FAV "*"
            
        printf "+$(printf '%*s' $((WIDTH_NR + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_NAME + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_IP + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_UPTIME + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_PORTS + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_FAV + 2)) | tr ' ' '-')+\n"
    else
        # Simple view - only number and container name
        printf "+$(printf '%*s' $((WIDTH_NR + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_NAME + 2)) | tr ' ' '-')+\n"
        
        printf "| %-*s | %-*s |\n" \
            $WIDTH_NR "Nr." \
            $WIDTH_NAME "Container Name"
            
        printf "+$(printf '%*s' $((WIDTH_NR + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_NAME + 2)) | tr ' ' '-')+\n"
    fi
    
    # Table content
    for i in "${!containers[@]}"; do
        local container="${containers[i]}"
        local ip uptime ports fav_marker
        
        # Truncate container name if it exceeds maximum display width
        local display_name="$container"
        if [ ${#container} -gt $WIDTH_NAME ]; then
            display_name="${container:0:$((WIDTH_NAME-3))}..."
        fi
        
        if [ "$show_detailed" = "true" ]; then
            # Get container info for detailed view
            ip=$(get_container_ip "$container")
            uptime=$(get_container_uptime "$container")
            ports=$(get_container_ports "$container")
            
            # Check if it's a favorite
            fav_marker=" "
            is_favorite "$container" && fav_marker="*"
            
            # Format ports for display
            ports=$(format_ports_for_display "$ports" $WIDTH_PORTS)
            
            printf "| %-*d | %-*s | %-*s | %-*s | %-*s | %-*s |\n" \
                $WIDTH_NR "$((i+1))" \
                $WIDTH_NAME "$display_name" \
                $WIDTH_IP "$ip" \
                $WIDTH_UPTIME "$uptime" \
                $WIDTH_PORTS "$ports" \
                $WIDTH_FAV "$fav_marker"
        else
            # Simple view - only number and name
            printf "| %-*d | %-*s |\n" \
                $WIDTH_NR "$((i+1))" \
                $WIDTH_NAME "$display_name"
        fi
    done
    
    # Table footer
    if [ "$show_detailed" = "true" ]; then
        printf "+$(printf '%*s' $((WIDTH_NR + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_NAME + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_IP + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_UPTIME + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_PORTS + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_FAV + 2)) | tr ' ' '-')+\n"
        echo
        [ -f "$FAVORITES_FILE" ] && echo "* = Favorite containers"
    else
        printf "+$(printf '%*s' $((WIDTH_NR + 2)) | tr ' ' '-')+$(printf '%*s' $((WIDTH_NAME + 2)) | tr ' ' '-')+\n"
    fi
    
    echo
    show_table_help
}

# Function to execute container shell
exec_container() {
    local container="$1"
    
    add_to_history "$container" "exec"
    
    # Try different shells in order of preference
    local shells=("/bin/bash" "/bin/sh" "/bin/zsh" "/bin/ash")
    
    for shell in "${shells[@]}"; do
        if docker exec "$container" test -f "$shell" 2>/dev/null; then
            print_color "$COLOR_SUCCESS" "Connecting to $container using $shell..."
            docker exec -it "$container" "$shell"
            return 0
        fi
    done
    
    # Fallback: try bash anyway (might work even if test fails)
    print_color "$COLOR_INFO" "Connecting to $container using /bin/bash..."
    docker exec -it "$container" /bin/bash
}

# Function to show container logs
show_logs() {
    local container="$1"
    local lines="${LOG_LINES:-$DEFAULT_LOG_LINES}"
    local follow="${2:-true}"
    
    add_to_history "$container" "logs"
    
    print_color "$COLOR_INFO" "Showing logs for $container (Ctrl+C to exit)..."
    
    if [ "$follow" = "true" ]; then
        docker logs --tail "$lines" --follow --timestamps "$container"
    else
        docker logs --tail "$lines" --timestamps "$container"
    fi
}

# Function to show container stats
show_stats() {
    local container="$1"
    
    add_to_history "$container" "stats"
    
    print_color "$COLOR_INFO" "Showing live stats for $container (Ctrl+C to exit)..."
    docker stats "$container"
}

# Function to show container info
show_info() {
    local container="$1"
    
    add_to_history "$container" "info"
    
    print_color "$COLOR_HEADER" "Container Information: $container"
    echo
    
    # Basic info
    local image status started ports network
    read -r image status started < <(docker inspect "$container" --format '{{.Config.Image}} {{.State.Status}} {{.State.StartedAt}}')
    network=$(docker inspect "$container" --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}} {{end}}')
    ports=$(get_container_ports "$container")
    
    echo "Image:     $image"
    echo "Status:    $status"
    echo "Started:   $started"
    echo "Networks:  $network"
    echo "Ports:     $ports"
    echo
    
    # Resource usage
    local memory_limit cpu_limit
    memory_limit=$(docker inspect "$container" --format '{{.HostConfig.Memory}}' | sed 's/0/unlimited/')
    cpu_limit=$(docker inspect "$container" --format '{{.HostConfig.CpuQuota}}' | sed 's/-1/unlimited/' | sed 's/0/unlimited/')
    
    echo "Memory Limit: $memory_limit"
    echo "CPU Limit:    $cpu_limit"
    echo
    
    # Environment variables (first 10)
    print_color "$COLOR_INFO" "Environment Variables (showing first 10):"
    docker inspect "$container" --format '{{range .Config.Env}}{{.}}{{"\n"}}{{end}}' | head -10
}

# Function to show port mappings
show_ports() {
    local container="$1"
    
    add_to_history "$container" "ports"
    
    print_color "$COLOR_HEADER" "Port Mappings: $container"
    echo
    
    local port_info
    port_info=$(docker port "$container" 2>/dev/null)
    
    if [ -n "$port_info" ]; then
        echo "$port_info"
    else
        echo "No port mappings found"
    fi
    echo
    
    # Also show exposed ports from image
    local exposed_ports
    exposed_ports=$(docker inspect "$container" --format '{{range $port, $conf := .Config.ExposedPorts}}{{$port}} {{end}}' 2>/dev/null)
    
    if [ -n "$exposed_ports" ]; then
        echo "Exposed ports: $exposed_ports"
    fi
}

# Function to restart container
restart_container() {
    local container="$1"
    
    add_to_history "$container" "restart"
    
    print_color "$COLOR_WARNING" "Restarting container: $container"
    if docker restart "$container" >/dev/null 2>&1; then
        print_color "$COLOR_SUCCESS" "Container restarted successfully"
    else
        print_color "$COLOR_ERROR" "Failed to restart container"
    fi
}

# Function to choose action
choose_action() {
    local container="$1"
    local action
    
    echo
    print_color "$COLOR_HEADER" "Actions for container '$container':"
    echo "1. Execute shell (interactive)"
    echo "2. Show logs (tail -f)"
    echo "3. Show live stats"
    echo "4. Show container info"
    echo "5. Show port mappings"
    echo "6. Restart container"
    echo "7. Add/Remove from favorites"
    echo "8. Show logs (static)"
    echo
    
    while true; do
        read -p "Choose action (1-8) or 'b' to go back: " action
        
        case "$action" in
            1|exec|shell)
                exec_container "$container"
                break
                ;;
            2|logs|log)
                show_logs "$container" "true"
                break
                ;;
            3|stats|stat)
                show_stats "$container"
                break
                ;;
            4|info)
                show_info "$container"
                read -p "Press Enter to continue..."
                return 1  # Go back to menu
                ;;
            5|ports|port)
                show_ports "$container"
                read -p "Press Enter to continue..."
                return 1  # Go back to menu
                ;;
            6|restart)
                restart_container "$container"
                read -p "Press Enter to continue..."
                return 1  # Go back to menu
                ;;
            7|fav|favorite)
                if is_favorite "$container"; then
                    remove_favorite "$container"
                else
                    add_favorite "$container"
                fi
                read -p "Press Enter to continue..."
                return 1  # Go back to menu
                ;;
            8|logs-static)
                show_logs "$container" "false"
                read -p "Press Enter to continue..."
                return 1  # Go back to menu
                ;;
            b|B|back)
                return 1  # Signal to go back
                ;;
            *)
                echo "Invalid choice. Please enter 1-8 or 'b' (back)."
                ;;
        esac
    done
    return 0
}

# Function for interactive selection
interactive_selection() {
    local containers=("$@")
    local choice
    
    while true; do
        display_containers "${containers[@]}"
        
        read -p "Choice: " choice
        
        case "$choice" in
            q|Q|quit|exit)
                echo "Goodbye!"
                exit 0
                ;;
            d|D|detailed)
                if [ "${DETAILED_VIEW:-false}" = "true" ]; then
                    DETAILED_VIEW="false"
                    print_color "$COLOR_INFO" "Switched to simple view"
                else
                    DETAILED_VIEW="true" 
                    print_color "$COLOR_INFO" "Switched to advanced view"
                fi
                continue
                ;;
            f|F|favorites)
                show_favorites
                continue
                ;;
            h|H|history)
                show_history
                continue
                ;;
            ''|*[!0-9]*)
                # Check if it's a container name (not a number)
                local found_container=""
                for container in "${containers[@]}"; do
                    if [ "$container" = "$choice" ]; then
                        found_container="$container"
                        break
                    fi
                done
                
                # If exact match not found, try partial matching
                if [ -z "$found_container" ]; then
                    local matches=()
                    for container in "${containers[@]}"; do
                        if [[ "$container" == *"$choice"* ]]; then
                            matches+=("$container")
                        fi
                    done
                    
                    case ${#matches[@]} in
                        0)
                            print_color "$COLOR_WARNING" "No container found matching '$choice'. Please try again."
                            continue
                            ;;
                        1)
                            found_container="${matches[0]}"
                            ;;
                        *)
                            print_color "$COLOR_INFO" "Multiple matches found for '$choice':"
                            printf "  - %s\n" "${matches[@]}"
                            echo "Please be more specific."
                            continue
                            ;;
                    esac
                fi
                
                if [ -n "$found_container" ]; then
                    print_color "$COLOR_SUCCESS" "Selected container: $found_container"
                    if choose_action "$found_container"; then
                        break
                    fi
                    # If choose_action returns 1 (back), continue the loop
                else
                    print_color "$COLOR_WARNING" "Invalid input. Please enter a number, container name, or command."
                fi
                ;;
            *)
                if [ "$choice" -ge 1 ] && [ "$choice" -le ${#containers[@]} ]; then
                    local selected_container="${containers[$((choice-1))]}"
                    print_color "$COLOR_SUCCESS" "Selected container: $selected_container"
                    if choose_action "$selected_container"; then
                        break
                    fi
                    # If choose_action returns 1 (back), continue the loop
                else
                    print_color "$COLOR_WARNING" "Invalid choice. Please enter a number between 1 and ${#containers[@]}, container name, or command."
                fi
                ;;
        esac
    done
}

# Function to show favorites
show_favorites() {
    if [ ! -f "$FAVORITES_FILE" ] || [ ! -s "$FAVORITES_FILE" ]; then
        print_color "$COLOR_INFO" "No favorite containers saved."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color "$COLOR_HEADER" "Favorite Containers:"
    echo
    
    local num=1
    while IFS= read -r container; do
        # Check if container is still running
        if docker ps --format "{{.Names}}" | grep -q "^$container$"; then
            printf "%2d. %s (running)\n" "$num" "$container"
        else
            printf "%2d. %s (not running)\n" "$num" "$container"
        fi
        ((num++))
    done < "$FAVORITES_FILE"
    
    echo
    read -p "Enter number to select, or press Enter to go back: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        local selected_container
        selected_container=$(sed -n "${choice}p" "$FAVORITES_FILE")
        
        if [ -n "$selected_container" ]; then
            if docker ps --format "{{.Names}}" | grep -q "^$selected_container$"; then
                choose_action "$selected_container"
            else
                print_color "$COLOR_WARNING" "Container '$selected_container' is not running."
                read -p "Press Enter to continue..."
            fi
        fi
    fi
}

# Function to show history
show_history() {
    if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
        print_color "$COLOR_INFO" "No history available."
        read -p "Press Enter to continue..."
        return
    fi
    
    print_color "$COLOR_HEADER" "Recent Activity:"
    echo
    
    printf "%-19s %-25s %s\n" "Time" "Container" "Action"
    printf "%-19s %-25s %s\n" "-------------------" "-------------------------" "--------"
    
    head -10 "$HISTORY_FILE" | while IFS='|' read -r timestamp container action; do
        printf "%-19s %-25s %s\n" "$timestamp" "$container" "$action"
    done
    
    echo
    read -p "Press Enter to continue..."
}

# Main logic
main() {
    check_docker
    
    # Get list of running containers
    local docker_output
    docker_output=$(get_containers)
    
    if [ -z "$docker_output" ]; then
        print_color "$COLOR_INFO" "No running containers found."
        exit 0
    fi
    
    # Convert to array
    mapfile -t containers < <(echo "$docker_output")
    
    # Check if container name was provided as argument
    if [ $# -eq 1 ]; then
        local target="$1"
        
        # Check if container exists (exact match)
        for container in "${containers[@]}"; do
            if [ "$container" = "$target" ]; then
                print_color "$COLOR_SUCCESS" "Found container: $target"
                if choose_action "$target"; then
                    exit 0
                else
                    # User chose to go back, show interactive menu
                    interactive_selection "${containers[@]}"
                    exit 0
                fi
            fi
        done
        
        # Fuzzy matching for partial names
        local matches=()
        for container in "${containers[@]}"; do
            if [[ "$container" == *"$target"* ]]; then
                matches+=("$container")
            fi
        done
        
        case ${#matches[@]} in
            0)
                print_color "$COLOR_ERROR" "Container '$target' not found among running containers."
                echo "Available containers:"
                printf "  - %s\n" "${containers[@]}"
                exit 1
                ;;
            1)
                print_color "$COLOR_SUCCESS" "Found partial match: ${matches[0]}"
                if choose_action "${matches[0]}"; then
                    exit 0
                else
                    # User chose to go back, show interactive menu
                    interactive_selection "${containers[@]}"
                    exit 0
                fi
                ;;
            *)
                print_color "$COLOR_INFO" "Multiple matches found for '$target':"
                interactive_selection "${matches[@]}"
                ;;
        esac
    else
        # No arguments - show interactive menu
        if [ ${#containers[@]} -eq 1 ]; then
            print_color "$COLOR_INFO" "Only one container running: ${containers[0]}"
            read -p "Connect to it? [Y/n]: " confirm
            if [[ "$confirm" =~ ^[Nn] ]]; then
                exit 0
            fi
            choose_action "${containers[0]}"
        else
            interactive_selection "${containers[@]}"
        fi
    fi
}

# Show usage if help is requested
if [ $# -gt 0 ] && [[ "$1" =~ ^(-h|--help)$ ]]; then
    print_color "$COLOR_HEADER" "Advanced Docker Container Manager"
    echo
    echo "Usage: $0 [container_name] [options]"
    echo ""
    echo "Options:"
    echo "  container_name    Connect to named container (supports partial matching)"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Interactive Features:"
    echo "  • Execute shell (bash/sh/zsh/ash)"
    echo "  • View logs (live or static)"
    echo "  • Monitor live stats"
    echo "  • Show detailed container info"
    echo "  • Display port mappings"
    echo "  • Restart containers"
    echo "  • Manage favorites"
    echo "  • View command history"
    echo "  • Toggle detailed/simple view"
    echo ""
    echo "Navigation:"
    echo "  • Use numbers or container names for selection"
    echo "  • 'd' - Toggle detailed view"
    echo "  • 'f' - Show favorites"
    echo "  • 'h' - Show history"
    echo "  • 'q' - Quit"
    echo ""
    echo "Config files are stored in: $CONFIG_DIR"
    exit 0
fi

# Run main function
main "$@"
