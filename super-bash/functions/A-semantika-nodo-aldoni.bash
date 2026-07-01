#!/bin/bash
# ============================================================================
# A‑semantika nodo aldoni — bash wrapper functions
# ============================================================================
#
# Requires: `A semantika nodo aldoni` CLI from the A‑semantika package
#           (https://github.com/your-org/autish/tree/main/A-semantika).
#
# Source this file from your .bashrc / .bash_profile:
#   source ~/.basculer/super-bash/functions/A-semantika-nodo-aldoni.bash
#
# Naming convention:
#   - Public functions:  node_id(), sna*() — intended for interactive use.
#   - Internal helpers:  _command_node_id(), _general_person_band_node_id()
#                        — prefixed with underscore, not called directly.
#
# ID generation: uses a manual sed substitution table covering Latin + Esperanto
# accented characters.  For full Unicode support, use A‑semantika's Python CLI
# directly (which uses unicodedata NFKD decomposition).
# ============================================================================

# ------------------------------------------------------------
# node_id   — sanitise a string to uppercase ASCII node ID
#
# Replaces Esperanto/Latin diacritics → plain letter,
# collapses non‑alphanumeric → underscore.
#
# $1 : raw input string
# stdout : sanitised ID (e.g. "Poincaré" → "POINCARE")
# ------------------------------------------------------------

node_id() {
  local s="$1"

  # Trim leading/trailing whitespace
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"

  # Uppercase first (final target case)
  s="${s^^}"

  # Strip all diacritics from uppercase letters (including Esperanto)
  s=$(
    printf '%s' "$s" | sed \
      -e 's/[ÀÁÂÃÄÅĀĂĄ]/A/g' \
      -e 's/[ÇĆĈĊČ]/C/g' \
      -e 's/[ĎĐ]/D/g' \
      -e 's/[ÈÉÊËĒĔĖĘĚ]/E/g' \
      -e 's/[ĜĞĠĢ]/G/g' \
      -e 's/[ĤĦ]/H/g' \
      -e 's/[ÌÍÎÏĨĪĬĮİ]/I/g' \
      -e 's/[Ĵ]/J/g' \
      -e 's/[Ķ]/K/g' \
      -e 's/[ĹĻĽĿŁ]/L/g' \
      -e 's/[ÑŃŅŇ]/N/g' \
      -e 's/[ÒÓÔÕÖŌŎŐ]/O/g' \
      -e 's/[ŔŖŘ]/R/g' \
      -e 's/[ŚŜŞŠ]/S/g' \
      -e 's/[ŢŤŦ]/T/g' \
      -e 's/[ÙÚÛÜŨŪŬŮŰŲ]/U/g' \
      -e 's/[Ŵ]/W/g' \
      -e 's/[ÝŸŶ]/Y/g' \
      -e 's/[ŹŻŽ]/Z/g'
  )

  # Replace any non‑alphanumeric (A-Z,0-9) or underscore with underscore
  s="${s//[^0-9A-Z_]/_}"

  # Collapse consecutive underscores into a single underscore
  while [[ "$s" == *__* ]]; do
    s="${s//__/_}"
  done
  while [[ $s == *_ ]]; do s=${s%_}; done
  echo "$s"

}

# ------------------------------------------------------------
# _command_node_id — internal: extract first word of a CLI command
#                    and sanitise as a node ID.
#
# Strips flags/args after the first space (e.g. "git commit -m"
# → "git" → "GIT").
#
# $1 : CLI command string
# stdout : sanitised command name
# ------------------------------------------------------------
_command_node_id() {
  local prefix="${1%%[[:space:]]*}"
  node_id "$prefix"
}

# ------------------------------------------------------------
# Helper: Build ID for person or band (prefix + initials of
#         all but last word + full last word). Each word is
#         sanitised individually with node_id().
# ------------------------------------------------------------
_general_person_band_node_id() {
  local prefix="$1" # "H" or "MB"
  local input="$2"
  # Split input into words using default whitespace
  local words=()
  read -ra words <<<"$input"

  local -a sanitised_words=()
  local word
  for word in "${words[@]}"; do
    sanitised_words+=("$(node_id "$word")")
  done

  # Last word is the surname
  local last_word="${sanitised_words[-1]}"
  # First letters of all words except the last
  local initials=""
  local len=${#sanitised_words[@]}
  for ((i = 0; i < len - 1; i++)); do
    local w="${sanitised_words[i]}"
    [[ -n "$w" ]] && initials+="${w:0:1}"
  done

  echo "${prefix}_${initials}${last_word}"
}

# ------------------------------------------------------------
# Public: Person node ID
#   Input: full name, e.g. "Shakira Ripoll"
#   Output: H_ + first letter of each given name + last name
# ------------------------------------------------------------
person_node_id() {
  _general_person_band_node_id "H" "$1"
}

# ------------------------------------------------------------
# Public: Music band node ID
#   Input: band name, e.g. "Pink Floyd"
#   Output: MB_ + first letter of each non‑last word + last word
# ------------------------------------------------------------
music_band_node_id() {
  _general_person_band_node_id "MB" "$1"
}

# ------------------------------------------------------------
# Public: Song node ID
#   Input: song title, e.g. "Livin' La Vida Loca"
#   Output: MK_ + first letter of every word (all words)
# ------------------------------------------------------------
song_node_id() {
  local title="$1"
  local words=()
  read -ra words <<<"$title"

  local initials=""
  local word
  for word in "${words[@]}"; do
    local sanitised="$(node_id "$word")"
    [[ -n "$sanitised" ]] && initials+="${sanitised:0:1}"
  done

  echo "MK_${initials}"
}
# ------------------------------------------------------------
# yt_id — extract YouTube video ID from a URL and prefix with YT_.
#
# Handles youtu.be/ID and youtube.com/watch?v=ID formats.
# Requires GNU grep (-oP). Does NOT work on macOS / BSD grep.
#
# $1 : YouTube URL
# stdout : YT_<video-id>  (e.g. "YT_dQw4w9WgXcQ")
# ------------------------------------------------------------
yt_id() { echo "YT_$(echo "$1" | grep -oP '(?<=youtu\.be/|v=)[^&?#]+')"; }

# ------------------------------------------------------------
# snar — create node with sanitised ID + labels in 3 languages.
#
# $1 : Esperanto label (also used as ID base via node_id)
# $2 : English label
# $3 : French label
# $@ : remaining args forwarded to `A semantika nodo aldoni`
#       (e.g. -y for auto‑confirm, -t TYPE)
# stdout : CLI output from A‑semantika
# ------------------------------------------------------------
snar() {
  A semantika nodo aldoni "$(node_id "$1")" -e "eo::$1" -e "en::$2" -e "fr::$3" -k "${@:4}"
}

# ------------------------------------------------------------
# sna — create node with explicit base ID + labels in 3 languages.
#
# $1 : arbitrary string used as ID base (via node_id)
# $2 : Esperanto label
# $3 : English label
# $4 : French label
# $@ : remaining args forwarded (e.g. -y)
# ------------------------------------------------------------
sna() {
  A semantika nodo aldoni "$(node_id "$1")" -e "eo::$2" -e "en::$3" -e "fr::$4" -k "${@:5}"
}

# ------------------------------------------------------------
# snak — create node with sanitised ID + arbitrary flags (no labels).
#
# $1 : ID base (via node_id)
# $@ : remaining args forwarded (e.g. -t TYPE, -y)
# ------------------------------------------------------------
snak() {
  A semantika nodo aldoni "$(node_id "$1")" -k "${@:2}"
}

# ------------------------------------------------------------
# snac — create CLI‑command node.
#
# $1 : type node ID (e.g. "GIT", "DOCKER")
# $2 : CLI command string (used as label + ID suffix)
# $@ : remaining args forwarded
# ------------------------------------------------------------
snac() {
  A semantika nodo aldoni "CLI_KOMANDO_$(_command_node_id "$2")" -e "$2 (CLI komando)" -t $1 -k "${@:3}"
}

# ------------------------------------------------------------
# snay — create YouTube video node.
#
# $1 : YouTube URL (extracts video ID via yt_id)
# $@ : remaining args forwarded
# ------------------------------------------------------------
snay() {
  A semantika nodo aldoni "$(yt_id "$1")" -k "${@:2}" -t YT_FILMETO
}

# ------------------------------------------------------------
# snap — create person node.
#
# Sanitised ID:  H_<initials><SURNAME>
# Label:         full name
# Type:          HOMO_SAPIENS
#
# $1 : full name (e.g. "Shakira Ripoll")
# $@ : remaining args forwarded
# ------------------------------------------------------------
snap() {
  A semantika nodo aldoni "$(person_node_id "$1")" -e "$1" -t HOMO_SAPIENS -k "${@:2}"
}

# ------------------------------------------------------------
# snab — create music‑band node.
#
# Sanitised ID:  MB_<initials><LASTWORD>
# Label:         band name
# Type:          MUZIKBANDO
#
# $1 : band name (e.g. "Pink Floyd")
# $@ : remaining args forwarded
# ------------------------------------------------------------
snab() {
  A semantika nodo aldoni "$(music_band_node_id "$1")" -e "$1" -t MUZIKBANDO -k "${@:2}"
}

# ------------------------------------------------------------
# snal — create book (LIBRO) node with ISBN-based ID.
#
# Sanitised ID:  ISBN_<sanitized-isbn>
# Labels:        Esperanto, English, French
# Type:          LIBRO
#
# $1 : ISBN number (e.g. "978-0-123-45678-9")
# $2 : Esperanto title
# $3 : English title
# $4 : French title
# $@ : remaining args forwarded (e.g. -y for auto‑confirm)
# stdout : CLI output from A‑semantika
# ------------------------------------------------------------
snal() {
  A semantika nodo aldoni "ISBN_$(node_id "$1")" -e "eo:$2" -e "en:$3" -e "fr:$4" -t LIBRO -k -y "${@:5}"
}

# ------------------------------------------------------------
# snas — create song node.
#
# Sanitised ID:  MK_<first‑letter‑of‑each‑word>
# Label:         song title
# Type:          KANTO
#
# $1 : song title (e.g. "Livin' La Vida Loca")
# $@ : remaining args forwarded
# ------------------------------------------------------------
snas() {
  A semantika nodo aldoni "$(song_node_id "$1")" -e "$1" -t KANTO -k "${@:2}"
}

# ------------------------------------------------------------
# snayc — create YouTube channel node.
#
# Sanitised ID:  YT<sanitized-channel-name> (e.g. "YTVERITASIUM")
# Label:         channel name as provided
#
# $1 : YouTube channel name (e.g. "@veritasium" or "Veritasium")
# $@ : remaining args forwarded (e.g. -y for auto‑confirm)
# stdout : CLI output from A‑semantika
# ------------------------------------------------------------
snayc() {
  A semantika nodo aldoni "YT$(node_id "_$1")" -e "eo:$1 (Youtube Kanalo)" -e "en:$1 (Youtube channel)" -e "fr:$1 (chaîne Youtube)" -k "${@:2}"
}
