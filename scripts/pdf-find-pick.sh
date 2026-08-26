set -euo pipefail
pdf-find-list | fzf \
  --ansi \
  --exact \
  --no-multi \
  --color=16 \
  --info=inline \
  --delimiter=$'\t' \
  --with-nth=3 \
  --prompt='name> ' \
  --header='ctrl-t full text   ctrl-f names   ctrl-/ preview   enter open' \
  --preview='pdf-find-preview {1} {2} {q}' \
  --preview-window='right,55%,wrap,border-left' \
  --bind='ctrl-/:toggle-preview' \
  --bind='ctrl-t:change-prompt(text> )+reload(pdf-find-pages)' \
  --bind='ctrl-f:change-prompt(name> )+reload(pdf-find-list)' \
  --bind='enter:become:pdf-find-open {1} {2}'
