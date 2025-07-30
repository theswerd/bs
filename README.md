# bs - Ben's BS Manager

A basic hierarchical bash script manager that lets me manage command easily.

## Requirements

- **bash** (or compatible shell)
- **jq** - JSON processor for data manipulation

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

### More Examples

```bash
# Development workflow
bs add server "python -m http.server 8000" -n "Start dev server"
bs add logs "tail -f /var/log/app.log" -n "Watch application logs"
bs add backup "rsync -av ~/projects/ ~/backups/" -n "Backup projects"

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

| Command                              | Description                                 | Example                                        |
| ------------------------------------ | ------------------------------------------- | ---------------------------------------------- |
| `add <name> <command...>`            | Store a new command                         | `bs add hello "echo 'Hello World!'"`           |
| `add <name> <command...> -n "notes"` | Store command with notes                    | `bs add deploy "git push" -n "Deploy to prod"` |
| `rm <name...>`                       | Remove one or more commands                 | `bs rm deploy build test`                      |
| `ls [prefix]`                        | List commands (optionally filter by prefix) | `bs ls git`                                    |
| `<name> [args...]`                   | Execute stored command with optional args   | `bs deploy --force`                            |
| `--local`                            | Use local `.bs.json` only                   | `bs --local add test "npm test"`               |
| `completion`                         | Output bash completion script               | `eval "$(bs completion)"`                      |
| `help`                               | Show help message                           | `bs help`                                      |

## File Structure

```
bs/
├── bs.sh                 # Main executable script
├── lib/
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
    "notes": "Build project for production"
  }
}
```

## Why not aliases?

1. Too much work to add them to the right files.

2. Too hard to organize and keep track of.

3. I think calling these commands `bs` is highly accurate.

## Author

Created by **Ben Swerdlow** ([@theswerd](https://github.com/theswerd)) because I hate long READMEs and have too much free time.
