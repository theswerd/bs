interface BsCommand {
  command: string;
  notes?: string;
  directory?: string;
}

interface BsDatabase {
  [key: string]: BsCommand;
}

export class BsManager {
  private database: BsDatabase = {};
  private currentDirectory = "/home/user";

  constructor() {
    // Initialize with some demo commands
    this.database = {
      hello: {
        command: 'echo "Hello World!"',
        notes: "My first bs command",
      },
      status: {
        command: 'echo "Everything is working great!"',
        notes: "Check system status",
      },
      freestyle: {
        command: "open freestyle",
      },
    };
  }

  processCommand(input: string): string {
    if (input === "bs freestyle") {
      window.open("https://docs.freestyle.sh", "_blank");
    }
    const parts = input.trim().split(" ");
    const command = parts[0];

    // Handle global --local flag
    let localMode = false;
    if (command === "bs" && parts[1] === "--local") {
      localMode = true;
      return this.processBsCommand(parts.slice(2), localMode);
    } else if (command === "bs") {
      return this.processBsCommand(parts.slice(1));
    } else if (command === "help") {
      return this.showHelp();
    } else if (command === "clear") {
      return "\x1b[2J\x1b[H";
    } else if (command === "ls") {
      return this.showLs();
    } else if (command === "pwd") {
      return this.currentDirectory;
    } else if (command === "whoami") {
      return "user";
    } else if (command === "date") {
      return new Date().toString();
    } else if (command === "echo") {
      return this.handleEcho(parts.slice(1));
    } else {
      return `bash: ${command}: command not found`;
    }
  }

  private processBsCommand(
    args: string[],
    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    _localMode: boolean = false
  ): string {
    if (args.length === 0) {
      return this.showBsHelp();
    }

    const subCommand = args[0];

    switch (subCommand) {
      case "add":
        return this.addCommand(args.slice(1));
      case "rm":
        return this.removeCommand(args.slice(1));
      case "ls":
        return this.listCommands(args.slice(1));
      case "completion":
        return this.showCompletion();
      case "mcp":
        return this.showMcp();
      case "help":
        return this.showBsHelp();
      default:
        // Try to run as stored command
        return this.runCommand(subCommand, args.slice(1));
    }
  }

  private addCommand(args: string[]): string {
    if (args.length < 2) {
      return "Error: add requires a name and command";
    }

    const name = args[0];
    let command = "";
    let notes = "";
    let directory = "";
    let i = 1;

    // Parse command and options
    while (i < args.length) {
      if ((args[i] === "-n" || args[i] === "--notes") && i + 1 < args.length) {
        notes = args[i + 1];
        i += 2;
      } else if (
        (args[i] === "-d" || args[i] === "--dir") &&
        i + 1 < args.length
      ) {
        directory = args[i + 1];
        i += 2;
      } else if (args[i] === "--cd") {
        directory = this.currentDirectory;
        i++;
      } else {
        command += (command ? " " : "") + args[i];
        i++;
      }
    }

    if (!command) {
      return "Error: no command specified";
    }

    const cmdObj: BsCommand = { command, notes, directory };
    if (!notes) delete cmdObj.notes;
    if (!directory) delete cmdObj.directory;

    this.database[name] = cmdObj;
    let result = `Added command '${name}': ${command}`;
    if (notes) result += ` [${notes}]`;
    if (directory) result += ` (runs in ${directory})`;
    return result;
  }

  private removeCommand(args: string[]): string {
    if (args.length === 0) {
      return "Error: rm requires at least one command name";
    }

    const removed: string[] = [];
    for (const name of args) {
      if (this.database[name]) {
        delete this.database[name];
        removed.push(name);
      }
    }

    if (removed.length === 0) {
      return `No commands found: ${args.join(", ")}`;
    }

    return `Removed: ${removed.join(", ")}`;
  }

  private listCommands(args: string[]): string {
    const prefix = args[0] || "";
    const commands = Object.keys(this.database);

    if (commands.length === 0) {
      return "No commands stored";
    }

    const filtered = prefix
      ? commands.filter((name) => name.startsWith(prefix))
      : commands;

    if (filtered.length === 0) {
      return `No commands found with prefix: ${prefix}`;
    }

    const output: string[] = [];
    for (const name of filtered.sort()) {
      const cmd = this.database[name];
      const line = `${name}: ${cmd.command}${
        cmd.notes ? ` [${cmd.notes}]` : ""
      }`;
      output.push(line);
    }

    return output.join("\n");
  }

  private runCommand(name: string, args: string[]): string {
    const cmd = this.database[name];
    if (!cmd) {
      return `Command not found: ${name}`;
    }

    // Simulate command execution
    const fullCommand =
      cmd.command + (args.length > 0 ? " " + args.join(" ") : "");

    // Handle some basic commands for demo
    if (cmd.command.includes("echo")) {
      const match =
        cmd.command.match(/echo\s+["']([^"']+)["']/) ||
        cmd.command.match(/echo\s+(.+)/);
      if (match) {
        return match[1].replace(/['"]/g, "");
      }
    }

    return `Executed: ${fullCommand}`;
  }

  private showBsHelp(): string {
    return `bs - Ben's BS Manager

USAGE:
    bs [--local] <command> [options]

GLOBAL OPTIONS:
    --local                   Use local .bs.json in current directory only

COMMANDS:
    add <name> <command...>   Add or replace a command entry
        --notes, -n           Add notes for the command
        --dir, -d <path>      Always run command in specified directory
        --cd                  Always run command in current directory
    rm  <name...>             Remove one or more command entries
    ls  [prefix]              List entries (optional prefix filter)
    completion                Output bash completion script
    mcp                       Start MCP server for AI assistant integration
    help                      Show this help message

Examples:
    bs add hello "echo Hello!" -n "Greeting command"
    bs add deploy "git push" --dir ~/projects/myapp
    bs ls
    bs hello
    bs rm hello`;
  }

  private showHelp(): string {
    return `
This is a demo terminal — I re-implemented the basic functionality of bs for demonstration purposes.

\x1b[36mBasic commands:\x1b[0m
  help      - Show this help
  ls        - List files (demo)
  pwd       - Show current directory
  whoami    - Show current user
  date      - Show current date
  echo      - Echo text to terminal
  clear     - Clear terminal

\x1b[36mbs commands:\x1b[0m
  bs help   - Show bs help
  bs add    - Add a command
  bs ls     - List stored commands
  bs rm     - Remove a command

\x1b[33mThis is a demo terminal. Try: echo Hello World!\x1b[0m`;
  }

  private showLs(): string {
    return `\x1b[36mtotal 8\x1b[0m
drwxr-xr-x  3 user user  96 Jan 15 10:30 \x1b[34m.\x1b[0m
drwxr-xr-x  7 user user 224 Jan 15 10:25 \x1b[34m..\x1b[0m
-rw-r--r--  1 user user 156 Jan 15 10:30 \x1b[32m.bs.json\x1b[0m
-rw-r--r--  1 user user  24 Jan 15 10:25 demo.txt
drwxr-xr-x  2 user user  64 Jan 15 10:29 \x1b[34mprojects\x1b[0m`;
  }

  private showCompletion(): string {
    return `# bs completion script
# Add this to your ~/.bashrc or ~/.zshrc:
eval "$(bs completion)"

# For demonstration purposes, here's what the completion script would contain:
_bs_completion() {
    local cur prev commands
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    commands="add rm ls completion mcp help"

    if [[ \${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "\${commands}" -- \${cur}) )
    fi
}
complete -F _bs_completion bs`;
  }

  private showMcp(): string {
    return `[MCP-INFO] Starting MCP server: bs-mcp-server`;
  }

  private handleEcho(args: string[]): string {
    if (args.length === 0) {
      return "";
    }
    return args.join(" ");
  }
}
