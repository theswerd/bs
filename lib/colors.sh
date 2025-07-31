#!/usr/bin/env bash
# Color definitions for bs

# ANSI color codes
readonly BOLD='\033[1m'
readonly BLUE='\033[34m'
readonly CYAN='\033[36m'
readonly GRAY='\033[90m'
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
