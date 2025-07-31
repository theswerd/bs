# bs - Ben's BS Manager

A basic hierarchical bash script manager that lets me manage command easily.

## Requirements

- **bash** (or compatible shell)
- **jq** - JSON processor for data manipulation

## Tab Completion

To enable tab completion:

**For Bash**, add to `~/.bashrc` or `~/.bash_profile`:

```bash
eval "$(bs completion)"
```

**For Zsh**, add to `~/.zshrc`:

```bash
autoload -U +X compinit && compinit
autoload -U +X bashcompinit && bashcompinit
eval "$(bs completion)"
```

## Usage

### Hierarchical Database System

bs uses a hierarchical system that searches for `.bs.json` files:

```txt
/home/ben/projects/myapp/     ← Current directory (.bs.json)
/home/ben/projects/           ← Parent directory (.bs.json)
/home/ben/                    ← Home directory (.bs.json)
```

Commands in closer directories override those in parent directories.

### Local Mode

Use `--local` to work only with the current directory's `.bs.json`:

```bash
# Add project-specific command
bs --local add test "npm test" -n "Run project tests"

# List only local commands
bs --local ls

# Remove from local database only
bs --local rm test
```

### Directory-Specific Commands

Commands can be configured to always run in a specific directory:

```bash
# Always run in a specific directory
bs add deploy "git push && ./deploy.sh" --dir ~/projects/myapp -n "Deploy application"

# Always run in the directory where you added the command
bs add build "npm run build" --cd -n "Build in project directory"

# When you run these commands, bs will automatically change to the specified directory:
bs deploy  # Runs in ~/projects/myapp regardless of current location
bs build   # Runs in the directory where you originally added the command
```

The directory information is displayed when listing commands:

```text
deploy: git push && ./deploy.sh [Deploy application] (runs in /home/user/projects/myapp)
build: npm run build [Build in project directory] (runs in /home/user/projects/myapp)
```

### More Examples

```bash
# Development workflow
bs add server "python -m http.server 8000" -n "Start dev server" --cd
bs add logs "tail -f /var/log/app.log" -n "Watch application logs"
bs add backup "rsync -av ~/projects/ ~/backups/" -n "Backup projects"

# Directory-specific commands
bs add list-home "ls -la" --dir ~ -n "List files in home directory"
bs add build "npm run build" --cd -n "Build project in current directory"
bs add deploy "git push && ssh server deploy.sh" --dir ~/projects/myapp -n "Deploy from project root"

# Git shortcuts
bs add gc "git commit -am" -n "Quick commit with message"
bs add gp "git push origin" -n "Push to origin branch"
bs add gs "git status --short" -n "Concise git status"

# System administration
bs add ports "lsof -i -P -n | grep LISTEN" -n "Show listening ports"
bs add disk "df -h | grep -E '^/dev/'" -n "Show disk usage"
bs add proc "ps aux | grep" -n "Find processes (usage: bs proc name)"
```

## Command Reference

## Command Reference

| Command                                | Description                                 | Example                                        |
| -------------------------------------- | ------------------------------------------- | ---------------------------------------------- |
| `add <name> <command...>`              | Store a new command                         | `bs add hello "echo 'Hello World!'"`           |
| `add <name> <command...> -n "notes"`   | Store command with notes                    | `bs add deploy "git push" -n "Deploy to prod"` |
| `add <name> <command...> --dir <path>` | Store command that runs in specific dir     | `bs add build "make" --dir ~/project`          |
| `add <name> <command...> --cd`         | Store command that runs in current dir      | `bs add test "npm test" --cd`                  |
| `rm <name...>`                         | Remove one or more commands                 | `bs rm deploy build test`                      |
| `ls [prefix]`                          | List commands (optionally filter by prefix) | `bs ls git`                                    |
| `<name> [args...]`                     | Execute stored command with optional args   | `bs deploy --force`                            |
| `--local`                              | Use local `.bs.json` only                   | `bs --local add test "npm test"`               |
| `completion`                           | Output bash completion script               | `eval "$(bs completion)"`                      |
| `help`                                 | Show help message                           | `bs help`                                      |

## File Structure

```text
bs/
├── bs.sh                 # Main executable script
├── lib/
│   ├── colors.sh        # Color definitions and helper functions
│   ├── config.sh        # Configuration and database management
│   ├── commands.sh      # Core command operations (add/remove/list/run)
│   ├── completion.sh    # Tab completion functionality
│   └── help.sh          # Usage information
└── README.md            # This file
```

## Database Format

Commands are stored in JSON format:

```json
{
  "deploy": {
    "command": "git push origin main && ssh server 'cd /app && git pull'",
    "notes": "Deploy to production server"
  },
  "build": {
    "command": "npm run build",
    "notes": "Build project for production",
    "directory": "/home/user/projects/myapp"
  },
  "test": {
    "command": "npm test",
    "notes": "Run test suite",
    "directory": "/home/user/projects/myapp"
  }
}
```

## Why not aliases?

1. Too much work to add them to the right files.

2. Too hard to organize and keep track of.

3. I think calling these commands `bs` is highly accurate.

## Author

Created by **Ben Swerdlow** ([@theswerd](https://github.com/theswerd)) because I hate long READMEs and have too much free time.
