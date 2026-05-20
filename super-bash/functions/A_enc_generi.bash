aeg() {
  local converted
  converted=$(printf '%s' "$1" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 'y/ĉĈĝĜĥĤĵĴŝŜŭŬáàâäãåéèêëíìîïóòôõöúùûüçñ/cCgGhHjJsSuUaaaaaaeeeeiiiiooooouuuucn/' -e 's/ /-/g')
  agento generi -f enc -v -i -K "$converted" -- "$1"
}
