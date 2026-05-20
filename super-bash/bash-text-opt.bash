combine() {
  local file1="$1" file2="$2" merged="merged"
  cp "$file1"{,.bak} && cp "$file2"{,.bak} || return 1
  (
    sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//;s/[[:space:]]+/ /g' "$file1"
    sed -E 's/^[[:space:]]+//;s/[[:space:]]+$//;s/[[:space:]]+/ /g' "$file2"
  ) | awk 'NF && !seen[$0]++' >"$merged" || return 1
  cp "$merged" "$file1" && cp "$merged" "$file2" && rm "$merged"
}
