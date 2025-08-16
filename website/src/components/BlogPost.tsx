import React, { useState, useEffect } from "react";
import Terminal from "./Terminal";

const BlogPost: React.FC = () => {
  const [isTerminalOpen, setIsTerminalOpen] = useState(false);
  const [isMobile, setIsMobile] = useState(false);

  useEffect(() => {
    const checkScreenSize = () => {
      const mobile = window.innerWidth < 1024; // lg breakpoint
      setIsMobile(mobile);
      // Reset terminal state when switching between desktop/mobile
      if (!mobile) {
        setIsTerminalOpen(true); // Always open on desktop
      } else {
        setIsTerminalOpen(false); // Always closed by default on mobile
      }
    };
    
    checkScreenSize();
    window.addEventListener('resize', checkScreenSize);
    
    return () => window.removeEventListener('resize', checkScreenSize);
  }, []);

  return (
    <div className="h-screen flex bg-white prose">
      {/* Left Side - Blog Content */}
      <div className={`flex-1 px-16 py-20 pr-12 pl-8 overflow-y-auto bg-white ${isMobile ? 'w-full' : ''}`}>
        <article className="max-w-3xl mx-auto">
          {/* Header */}
          <header className="mb-12">
            <h1 className="text-2xl font-mono font-semibold text-black mb-2">
              bs - Ben's BS Manager
            </h1>
            <p className="text-lg text-gray-900 font-mono mb-2">
              A basic hierarchical bash script manager that lets me manage
              scripts easily.
            </p>
            <p>August 15, 2025</p>
          </header>

          {/* Blog Content */}
          <div className="prose prose-gray max-w-none">
            {/* Introduction */}
            <section className="mb-12">
              <p className="text-gray-900 leading-relaxed mb-4">
                <a
                  href="https://github.com/theswerd/bs"
                  className="text-green-700  underline"
                >
                  bs
                </a>{" "}
                is an experimental project to make managing scripts easier. My
                company{" "}
                <a
                  href="https://docs.freestyle.sh"
                  className="text-green-700  underline"
                >
                  Freestyle
                </a>{" "}
                relies a lot on scripts directories to manage our
                infrastructure. We have scripts for debugging customer issues,
                deploying new versions, and driving everything we do. All
                together, we probably have ~120 scripts across all our
                repositories. As the volume of our scripts grew, I started
                losing track of how to use them. We have READMEs, but in a
                crisis situation its easy to miss the README and struggle to
                find what you're looking for. I built BS as a simple solution
                for me to keep track of these scripts across projects, I then
                built a bunch of extras into it for fun.
              </p>
              <p className="text-gray-900 leading-relaxed mb-4">
                bs has a few things that make it special. bs is really simple,
                it doesn't have composition, dependency tracking or anything
                other than simple bashscript management. bs is written
                completely in bash scripts, and only relies on jq to work, so it
                works virtually anywhere with no setup. It is hierarchical,
                meaning you can have global scripts, project level scripts, and
                directory specific scripts that you define the availability of
                based on directory context. And, it has an MCP so AI can
                interact with it.
              </p>
              <p className="text-gray-900 leading-relaxed">
                bs also lets you refer to all of your bash scripts as <i>bs</i>{" "}
                which I really like.{" "}
                <b>
                  It is not made for production use cases and probably should
                  never be used. For production use cases, check out{" "}
                  <a
                    href="https://just.systems/"
                    className="text-green-700  underline"
                  >
                    just
                  </a>
                  .
                </b>
              </p>
            </section>

            {/* Architecture */}
            <section className="mb-12">
              <h2 className="text-2xl font-semibold text-terminal-green mb-6">
                BS Architecture
              </h2>
              <p className="text-gray-900 leading-relaxed mb-4">
                bs is powered by{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  .bs.json
                </span>{" "}
                files. Each file defines commands as key/value pairs. A command
                entry includes the actual shell command, optional notes, and (if
                needed) the directory where it should always be run.
                <div className="bg-[#1E1E1E] p-4 rounded-lg font-mono text-sm my-4">
                  <pre className="text-white">
                    {`{
  "deploy": {
    "command": "git push origin main && ssh server 'cd /app && git pull'",
    "notes": "Deploy to production server"
  },
  "build": {
    "command": "npm run build",
    "notes": "Build project for production",
    "directory": "/home/user/projects/myapp"
  }
}`}
                  </pre>
                </div>
              </p>

              <p className="text-gray-900 leading-relaxed  mb-4">
                The cli will always look for{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  .bs.json
                </span>{" "}
                files in the current and all parent directories. It prefers
                command definitions in the current directory and closer parents
                over those in higher directories. This allows for
                project-specific overrides while still inheriting global
                commands from the home directory.
              </p>

              <div className="bg-[#1E1E1E] p-4 rounded-lg font-mono text-sm mb-4">
                <pre className="text-white">
                  {`/home/ben/project/subdir/     ← Current directory (.bs.json)
/home/ben/project/            ← Parent directory (.bs.json)
/home/ben/                    ← Home directory (.bs.json)`}
                </pre>
              </div>
              <p className="text-gray-900 leading-relaxed  mb-4">
                As a user of bs you never need to interact with .bs.json files
                directly, the CLI should handle everything.{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  bs add
                </span>{" "}
                can be used to add commands,{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  bs ls
                </span>{" "}
                lists available commands{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  bs rm
                </span>{" "}
                can remove commands. and{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  bs {"<command>"}
                </span>{" "}
                executes a command.
              </p>
            </section>
            {/* Architecture */}
            <section className="mb-12">
              <h2 className="text-2xl font-semibold text-terminal-green mb-6">
                AI BS
              </h2>
              <p className="text-gray-900 leading-relaxed mb-4">
                bs has a built in MCP implemented in bash. You can run it with{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  bs mcp
                </span>
                . This MCP lets your AI Agents interact with the saved bs in
                your project. This is useful for letting your AI Agents to
                follow the processes you have defined in your scripts. This
                hasn't been that useful for me yet, but I have enjoyed it a
                little as I can now ask my AI to deploy, rollback and pull
                debugging information for me, which it failed to do before
                without explicitly pointing it at the correct READMEs every
                time.
              </p>
            </section>
            <section className="mb-12">
              <h2 className="text-2xl font-semibold text-terminal-green mb-6">
                Try BS
              </h2>
              <p className="text-gray-900 leading-relaxed mb-4">
                Clone the <a href="https://github.com/theswerd/bs">git repo</a>{" "}
                from{" "}
                <a
                  href="https://github.com/theswerd/bs"
                  className="underline text-green-700"
                >
                  https://github.com/theswerd/bs
                </a>
                , then add{" "}
                <span className="bg-[#1E1E1E] py-1 px-1 rounded-lg font-mono text-sm text-white">
                  bs.sh
                </span>{" "}
                to your path. <b>I don't recommend using bs in production.</b>
              </p>
              <p className="text-gray-900 leading-relaxed mb-4">
                You can also try something like it in the emulator I set up on
                this page.
              </p>
            </section>
            <section className="mb-12">
              <h2 className="text-2xl font-semibold text-terminal-green mb-6">
                BS Inspiration
              </h2>
              <p className="text-gray-900 leading-relaxed mb-4">
                The biggest inspiration for bs is package.json. I used to put so
                much in my package.json files when I was primarily a web
                developer, and I missed that once I got into Rust and systems
                programming in general. My team started creating scripts
                directories naturally, and organized them based on the projects
                they were relevant to, the choices I made for bs were heavily
                influenced by wanting a package.json like interface for them.
                Just is the more professional tool for this, I highly recommend
                people interested in bs check it out. I tried Just but couldn't
                get into it, it felt like too much for my work.
              </p>
            </section>
            {/* Footer */}
            <footer className={`mt-16 pt-8 border-t border-gray-300 ${isMobile ? 'mb-20' : ''}`}>
              <p className="text-gray-800 font-mono">
                Created by{" "}
                <a
                  href="https://github.com/theswerd"
                  className="text-terminal-green hover:underline"
                >
                  Ben Swerdlow
                </a>{" "}
                because I hate remembering scripts and long READMEs and{" "}
                <a href="https://docs.freestyle.sh" className=" underline">
                  Freestyle
                </a>{" "}
                has a lot of them.
              </p>
              <p className="text-gray-700 font-mono mt-2">
                <a
                  href="https://github.com/theswerd/bs"
                  className="hover:text-terminal-green"
                >
                  View on GitHub
                </a>
              </p>
            </footer>
          </div>
        </article>
      </div>

      {/* Desktop Terminal - Right Side */}
      {!isMobile && (
        <div className="w-1/2 h-screen">
          <Terminal />
        </div>
      )}

      {/* Mobile Terminal Modal */}
      {isMobile && (
        <>
          {/* Terminal Toggle Button */}
          <button
            onClick={() => setIsTerminalOpen(!isTerminalOpen)}
            className="fixed bottom-4 right-4 z-50 bg-black text-green-400 px-4 py-2 rounded-lg font-mono text-sm shadow-lg hover:bg-gray-800 transition-colors"
          >
            {isTerminalOpen ? '↓ Terminal' : '↑ Terminal'}
          </button>

          {/* Modal Overlay */}
          {isTerminalOpen && (
            <div className="fixed inset-0 z-40 bg-black bg-opacity-50" onClick={() => setIsTerminalOpen(false)} />
          )}

          {/* Terminal Modal */}
          <div
            className={`fixed inset-0 z-50 bg-black transition-transform duration-300 ease-in-out flex flex-col ${
              isTerminalOpen ? 'translate-y-0' : 'translate-y-full'
            }`}
          >
            {/* Modal Header */}
            <div className="flex items-center justify-between bg-gray-800 px-4 py-3 border-b border-gray-600 flex-shrink-0">
              <span className="text-green-400 font-mono text-sm">Terminal</span>
              <button
                onClick={() => setIsTerminalOpen(false)}
                className="text-gray-400 hover:text-white text-2xl leading-none w-8 h-8 flex items-center justify-center"
              >
                ×
              </button>
            </div>
            
            {/* Terminal Content */}
            <div className="flex-1 min-h-0">
              <Terminal />
            </div>
          </div>
        </>
      )}
    </div>
  );
};

export default BlogPost;
