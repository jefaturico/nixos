set -euo pipefail

rows_output=$(niri msg --json windows | jq -r '
  [.[]
    | .title = (if .title == null or .title == "" then "(untitled)" else .title end)
    | .app_id = (if .app_id == null or .app_id == "" then "(unknown)" else .app_id end)
    | [.id, "\(.app_id) — \"\(.title)\""]
    | @tsv]
  | .[]
')

[ -n "$rows_output" ] || exit 0
mapfile -t rows <<<"$rows_output"
ids=()
labels=()
for row in "${rows[@]}"; do
  ids+=("${row%%$'\t'*}")
  labels+=("${row#*$'\t'}")
done

if ! selected_index=$(printf '%s\n' "${labels[@]}" \
  | fuzzel --dmenu --index --prompt="Window: " --lines=20 --minimal-lines); then
  exit 0
fi
if [[ ! "$selected_index" =~ ^[0-9]+$ ]] \
  || [ "$selected_index" -ge "${#ids[@]}" ]; then
  echo "niri-window-menu: fuzzel returned an invalid index: $selected_index" >&2
  exit 1
fi

niri msg action focus-window --id "${ids[$selected_index]}"
