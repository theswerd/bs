#!/usr/bin/env bash
# Color definitions for bs

# Prevent double sourcing
[[ -n "${BS_COLORS_LOADED:-}" ]] && return 0
readonly BS_COLORS_LOADED=1

# ANSI color codes
readonly BOLD='\033[1m'
readonly BLUE='\033[34m'
readonly CYAN='\033[36m'
readonly GRAY='\033[90m'
readonly YELLOW='\033[33m'
readonly RESET='\033[0m'

# Color functions for consistent usage
color_bold() {
  printf "${BOLD}%s${RESET}" "$1"
}

color_blue() {
  printf "${BLUE}%s${RESET}" "$1"
}

color_cyan() {
  printf "${CYAN}%s${RESET}" "$1"
}

color_gray() {
  printf "${GRAY}%s${RESET}" "$1"
}

color_yellow() {
  printf "${YELLOW}%s${RESET}" "$1"
}

# Show reserved command message
show_reserved_message() {
  local cmd="$1"
  printf "🚧 $(color_yellow "Reserved for future use") 🚧\n" >&2
  printf "$(color_yellow "Command '$cmd' is reserved for future features")\n" >&2
}
