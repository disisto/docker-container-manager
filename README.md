# Advanced Docker Container Manager (dcon)

A comprehensive Docker container management tool with an intuitive interface featuring shell access, log viewing, stats monitoring, port mappings, favorites, and much more.

## Features

- **Interactive Shell Access** - Connect to containers with automatic shell detection (bash/sh/zsh/ash)
- **Live Log Viewing** - Follow logs with timestamps and configurable tail length
- **Real-time Stats** - Monitor CPU, memory, and network usage
- **Container Information** - Detailed container inspection and port mappings
- **Favorites System** - Mark frequently used containers for quick access
- **Command History** - Track your recent container interactions
- **Dynamic Tables** - Responsive column widths that adapt to your container names
- **Partial Name Matching** - Type partial names to quickly find containers
- **Detailed/Simple Views** - Toggle between compact and comprehensive displays
- **Container Management** - Restart containers directly from the interface

## Usage Options

### Option 1: Interactive Mode
List all running containers with an interactive selection menu:

```bash
dcon
```

**Interactive Commands:**
- `[1-9]` or `[container-name]` - Select container
- `d` - Toggle advanced view (shows IP, uptime, ports, favorites)
- `f` - Show only favorite containers
- `h` - View command history
- `q` - Quit

### Option 2: Direct Access
Connect directly to a specific container (supports partial matching):

```bash
dcon web-server
dcon web      # Matches containers with "web" in the name
```

## Container Actions

Once you select a container, you can:

1. **Execute Shell** - Interactive bash/sh session
2. **Show Logs (Live)** - `tail -f` with timestamps  
3. **Show Stats** - Real-time CPU/memory monitoring
4. **Container Info** - Detailed inspection data
5. **Port Mappings** - View all port configurations
6. **Restart Container** - Restart the selected container
7. **Manage Favorites** - Add/remove from favorites
8. **Show Logs (Static)** - View logs without following

## Display Examples

**Simple View:**
```
+-----+------------------+
| Nr. | Container Name   |
+-----+------------------+
| 1   | web-server       |
| 2   | database         |
+-----+------------------+

Quick commands:
  [1-9] | [name]    Select container    |  'd' Toggle advanced view     |  'f' Show favorites
  'h' Show history  |  'q' Quit          |  Partial names supported (e.g., 'web' matches 'web-server')
```

**Advanced View:**
```
+-----+------------------+-----------------+--------+------------+---+
| Nr. | Container Name   | IP Address      | Uptime | Ports      | * |
+-----+------------------+-----------------+--------+------------+---+
| 1   | web-server       | 172.17.0.2      | 2d     | 80→8080    |   |
| 2   | database         | 172.17.0.3      | 5h     | N/A        | * |
+-----+------------------+-----------------+--------+------------+---+
```

## Installation

### Global Installation (Recommended)

1. **Download and install directly:**
```bash
curl -JLO https://raw.githubusercontent.com/disisto/docker-container-manager/main/docker-container-manager.sh
chmod +x docker-container-manager.sh
sudo mv docker-container-manager.sh /usr/local/bin/dcon
```

2. **Use from anywhere:**
```bash
dcon
dcon nginx
dcon web
```

### Alternative: Shell Alias Method

1. **Place the script in your home directory:**
```bash
mv docker-container-manager.sh ~/.docker-container-manager.sh
```

2. **Add alias to your shell configuration:**
```bash
# For bash users
echo 'alias dcon="$HOME/.docker-container-manager.sh"' >> ~/.bashrc
source ~/.bashrc

# For zsh users  
echo 'alias dcon="$HOME/.docker-container-manager.sh"' >> ~/.zshrc
source ~/.zshrc
```

3. **Use the command:**
```bash
dcon
dcon web-server
```

## Installation Example for Debian/Ubuntu

```bash
# Install dependencies
sudo apt update && sudo apt install curl

# Download and install
curl -JLO https://raw.githubusercontent.com/disisto/docker-container-manager/main/docker-container-manager.sh
chmod +x docker-container-manager.sh

# Global installation
sudo mv docker-container-manager.sh /usr/local/bin/dcon

# Test installation
dcon --help
dcon
```

## Configuration

The tool automatically creates configuration files in `~/.docker-selector/`:

- **`favorites`** - Your favorite containers
- **`history`** - Recent command history  
- **`config`** - Tool settings (theme, log lines, etc.)

## Advanced Features

### Favorites Management
- Add containers to favorites with action menu option 7
- View only favorites with `f` command
- Favorites are marked with `*` in the table

### Command History
- All actions are automatically logged with timestamps
- View recent activity with `h` command
- Tracks exec, logs, stats, info, ports, and restart actions

### Dynamic Display
- Table columns automatically resize based on content
- Container names up to 50 characters fully displayed
- IP addresses and ports get optimal column width
- ASCII-compatible borders work in all terminals

### Flexible Matching
- Exact name matching: `dcon web-server`
- Partial matching: `dcon web` (finds web-server, web-app, etc.)
- Multiple partial matches show selection menu
- Case-sensitive matching for precision

## Requirements

- **Docker** - Must be installed and running
- **Bash** - Version 4.0+ recommended
- **Terminal** - Any standard terminal with ASCII support

## Tips

- Use `d` to toggle advanced view for more container information
- Partial names work great: `dcon db` instead of `dcon production-database-v2`
- Add frequently used containers to favorites for quick access
- Use `h` to see what you've been working on recently
- The tool remembers your last view preference (simple/advanced)

---

**Complete Docker container management in one powerful tool!** 🚀
