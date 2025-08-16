import React, { useEffect, useRef } from "react";
import { Terminal as XTerm } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import "@xterm/xterm/css/xterm.css";
import { BsManager } from "../lib/bs-manager";

const Terminal: React.FC = () => {
  const terminalRef = useRef<HTMLDivElement>(null);
  const xtermRef = useRef<XTerm | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const bsManagerRef = useRef<BsManager | null>(null);

  useEffect(() => {
    if (!terminalRef.current) return;

    // Initialize terminal
    const terminal = new XTerm({
      theme: {
        background: "#1a1a1a",
        foreground: "#e5e5e5",
        cursor: "#00ff00",
        cursorAccent: "#1a1a1a",
        selectionBackground: "#3a3a3a",
        black: "#000000",
        red: "#ff5555",
        green: "#00ff00",
        yellow: "#ffff55",
        blue: "#5555ff",
        magenta: "#ff55ff",
        cyan: "#55ffff",
        white: "#ffffff",
        brightBlack: "#555555",
        brightRed: "#ff5555",
        brightGreen: "#00ff00",
        brightYellow: "#ffff55",
        brightBlue: "#5555ff",
        brightMagenta: "#ff55ff",
        brightCyan: "#55ffff",
        brightWhite: "#ffffff",
      },
      fontFamily: "Geist Mono, monospace",
      fontSize: 14,
      lineHeight: 1.2,
      cursorBlink: true,
      cursorStyle: "block",
      scrollback: 1000,
    });

    // Initialize fit addon
    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);

    // Open terminal
    terminal.open(terminalRef.current);
    fitAddon.fit();

    // Initialize bs manager
    const bsManager = new BsManager();

    // Store refs
    xtermRef.current = terminal;
    fitAddonRef.current = fitAddon;
    bsManagerRef.current = bsManager;

    // Welcome message - use the same as bs help
    const welcomeMessage = bsManager.processCommand("bs");
    const welcomeLines = welcomeMessage.split("\n");
    welcomeLines.forEach((line) => terminal.writeln(line));
    terminal.writeln("");
    terminal.writeln(
      '\x1b[33mTry: bs add hello "echo Hello World!" -n "My first command"\x1b[0m'
    );
    terminal.writeln("");

    // Current command buffer
    let currentCommand = "";
    let mcpMode = false;
    const prompt = "$ ";

    // Show initial prompt
    terminal.write(prompt);

    // Handle user input
    const handleInput = (data: string) => {
      const char = data;

      // Check for Ctrl+C to exit MCP mode
      if (char === "\u0003") {
        // Ctrl+C
        if (mcpMode) {
          terminal.writeln("\n^C");
          terminal.writeln("[MCP-INFO] Server stopped");
          mcpMode = false;
          currentCommand = "";
          terminal.write(prompt);
          return;
        }
        // Regular Ctrl+C behavior
        terminal.writeln("\n^C");
        currentCommand = "";
        terminal.write(prompt);
        return;
      }

      // If in MCP mode, ignore all input except Ctrl+C
      if (mcpMode) {
        return;
      }

      if (char === "\r") {
        // Enter key
        terminal.writeln("");

        if (currentCommand.trim()) {
          // Check if this is the MCP command
          if (currentCommand.trim() === "bs mcp") {
            const result = bsManager.processCommand(currentCommand.trim());
            terminal.writeln(result);
            mcpMode = true;
            terminal.writeln("Press Ctrl+C to stop the server");
          } else {
            // Process other commands normally
            const result = bsManager.processCommand(currentCommand.trim());
            if (result) {
              // Handle multiline output properly
              const lines = result.split("\n");
              lines.forEach((line) => terminal.writeln(line));
            }
          }
        }

        if (!mcpMode) {
          currentCommand = "";
          terminal.write(prompt);
        } else {
          currentCommand = "";
          // Don't show prompt in MCP mode
        }
      } else if (char === "\u007F") {
        // Backspace
        if (currentCommand.length > 0) {
          currentCommand = currentCommand.slice(0, -1);
          terminal.write("\b \b");
        }
      } else if (char >= " ") {
        // Printable characters
        currentCommand += char;
        terminal.write(char);
      }
    };

    terminal.onData(handleInput);

    // Handle resize
    const handleResize = () => {
      fitAddon.fit();
    };
    window.addEventListener("resize", handleResize);

    return () => {
      window.removeEventListener("resize", handleResize);
      terminal.dispose();
    };
  }, []);

  return (
    <div className="terminal-container bg-black h-full flex flex-col">
      <div className="flex-1 bg-black overflow-hidden">
        <div
          ref={terminalRef}
          className="terminal h-full w-full bg-black"
          style={{ fontFamily: "Geist Mono, monospace" }}
        />
      </div>
    </div>
  );
};

export default Terminal;
