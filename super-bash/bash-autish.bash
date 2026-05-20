nk() {
  if [ -e "$1.enc" ]; then
    echo -e "Warning: $1.enc already exists\nAbort" >&2
    return 1
  fi
  cp Linux-komando-modelo.enc "$1".enc && nvim "$1".enc
}

ne() {
  if [ -e "$1.enc" ]; then
    echo -e "Warning: $1.enc already exists\nAbort" >&2
    return 1
  fi
  cp modelo.enc "$1".enc && nvim "$1".enc
}

nova-jaro-enc() {
  local year=$1
  cat <<EOL >"${year}.enc"
terminologio.eo="${year} (kalendara jaro)"
terminologio.fr="${year} (année calendrier)"
terminologio.en="${year} (calendar year)"
difino.eo="[jaro](#592e5797, rdf:type) de la [Gregoria kalendaro](#caaf64dc, wdt:P361)"
EOL
  realpath "${year}.enc" | xclip -selection clipboard
}
alias nj="nova-jaro-enc"

nova-jarcento-enc() {
  local century=$1
  cat <<EOL >"${century}a-jarcento.enc"
terminologio.eo="${century}a jarcento (kalendara jarcento)"
terminologio.fr="${century}e siècle (siècle calendrier)"
terminologio.en="${century}th century (calendar century)"
difino.eo="[jarcento](#8677ddbd, rdf:type) de la [Gregoria kalendaro](#caaf64dc, wdt:P361)"
EOL
  realpath "${century}a-jarcento.enc" | xclip -selection clipboard
}
alias njc="nova-jarcento-enc"
