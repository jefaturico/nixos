{ pkgs, ... }:

# Reading, annotating, and keeping records: PDFs and e-books in Zathura,
# annotation in Okular, office formats in LibreOffice, plain-text notes, and
# plain-text accounting. `find-document` is the single entry point that finds
# any of them and hands it to the right viewer.
let
  zathuraPackage = pkgs.zathura.override {
    plugins = [ pkgs.zathuraPkgs.zathura_pdf_mupdf ];
  };

  # Zathura is the fast reader; Okular owns annotation. `o` hands the current
  # file and page across without losing the reading position.
  zathuraOpenOkular = pkgs.writeShellApplication {
    name = "zathura-open-okular";
    text = ''
      file="''${1:-}"
      page="''${2:-1}"
      if [ -z "$file" ]; then
        exit 1
      fi

      case "$page" in
        *[!0-9]*|"")
          page=1
          ;;
      esac

      case "$file" in
        file://*)
          file="$(${pkgs.python3}/bin/python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(urllib.parse.urlparse(sys.argv[1]).path))' "$file")"
          ;;
      esac

      exec ${pkgs.kdePackages.okular}/bin/okular --page "$page" "$file"
    '';
  };

  findDocument = pkgs.writeShellApplication {
    name = "find-document";
    runtimeInputs = with pkgs; [
      coreutils
      fd
      fuzzel
      libreoffice
      util-linux
      zathuraPackage
    ];
    text = ''
      set -euo pipefail
      umask 077

      cache_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/find-document"
      index="$cache_dir/index"
      lock="$cache_dir/index.lock"
      max_age=300

      refresh_index() {
        local new_index

        mkdir -p "$cache_dir"
        exec 9>"$lock"
        flock 9
        new_index=$(mktemp "$cache_dir/index.XXXXXX")
        trap 'rm -f "$new_index"' RETURN

        # Hidden directories are omitted deliberately: this excludes internal
        # trees such as .cache, .config, .local, and .git while retaining every
        # arbitrarily named user-facing directory below $HOME.
        fd --type f --type l --color never --print0 --no-ignore \
          --extension pdf \
          --extension epub \
          --extension odt --extension ods --extension odp --extension odg \
          --extension odf --extension odb \
          --extension fodt --extension fods --extension fodp --extension fodg \
          --extension ott --extension ots --extension otp --extension otg \
          --extension sxw --extension sxc --extension sxi --extension sxd \
          --extension doc --extension docx \
          --extension xls --extension xlsx \
          --extension ppt --extension pptx \
          --extension rtf \
          . "$HOME" >"$new_index"

        mv -f "$new_index" "$index"
        trap - RETURN
      }

      case "''${1:-}" in
        --refresh)
          refresh_index
          exit
          ;;
        --help|-h)
          printf '%s\n' \
            'Usage: find-document [--refresh]' \
            "Fuzzy-find documents below $HOME and open them." \
            'The index refreshes in the background after five minutes.'
          exit
          ;;
        "") ;;
        *)
          printf 'find-document: unknown option: %s\n' "$1" >&2
          exit 2
          ;;
      esac

      if [[ ! -f "$index" ]]; then
        refresh_index
      elif (( $(date +%s) - $(stat -c %Y "$index") > max_age )); then
        "$0" --refresh >/dev/null 2>&1 &
      fi

      if ! selected_index=$("$HOME/.local/bin/fuzzel" \
        --dmenu0 \
        --index \
        --only-match \
        --no-run-if-empty \
        --prompt='Find document: ' \
        --lines=15 \
        --minimal-lines \
        --match-mode=fzf \
        --counter \
        <"$index"); then
        exit 0
      fi

      if [[ ! "$selected_index" =~ ^[0-9]+$ ]]; then
        printf 'find-document: fuzzel returned an invalid index: %s\n' "$selected_index" >&2
        exit 1
      fi

      mapfile -d "" -t documents <"$index"
      selected="''${documents[$selected_index]:-}"
      [[ -n "$selected" ]] || exit 0

      if [[ ! -f "$selected" ]]; then
        printf 'find-document: file no longer exists: %s\n' "$selected" >&2
        refresh_index
        exit 1
      fi

      case "''${selected,,}" in
        *.pdf|*.epub)
          setsid --fork zathura "$selected" >/dev/null 2>&1
          ;;
        *)
          setsid --fork libreoffice "$selected" >/dev/null 2>&1
          ;;
      esac
    '';
  };
in
{
  programs.zathura = {
    enable = true;
    package = zathuraPackage;
    options = {
      adjust-open = "width";
      continuous-hist-save = true;
      database = "sqlite";
      guioptions = "none";
      recolor = false;
      render-loading = false;
      sandbox = "normal";
      scroll-step = 80;
      selection-clipboard = "clipboard";
      statusbar-basename = true;
      window-title-basename = true;
    };
    mappings = {
      o = "exec \"${zathuraOpenOkular}/bin/zathura-open-okular '$FILE' $PAGE\"";
      n = "navigate previous";
      p = "navigate next";
      "<C-n>" = "scroll down";
      "<C-p>" = "scroll up";
    };
  };

  xdg.configFile = {
    "okularrc" = {
      force = true;
      text = ''
        MenuBar=Disabled

        [Desktop Entry]
        FullScreen=false

        [General]
        LockSidebar=true
        ShowSidebar=false

        [MainWindow]
        MenuBar=Disabled
      '';
    };

    "okularpartrc" = {
      force = true;
      text = ''
        [Core Performance]
        MemoryLevel=Low

        [Dlg Performance]
        EnableCompositing=false

        [General]
        MaxRecentItems=8
        ShowEmbeddedContentMessages=false
        ShowOSD=false
        ttsVoice=samantha

        [Main View]
        ShowBottomBar=false
        ShowLeftPanel=false

        [PageView]
        BackgroundColor=0,0,0
        PrimaryAnnotationToolBar=QuickAnnotationToolBar
        ShowScrollBars=false
        SmoothScrolling=false
        TrimMargins=true
        UseCustomBackgroundColor=true

        [Reviews]
        AnnotationContinuousMode=true
        QuickAnnotationDefaultAction=0
        QuickAnnotationTools=<tool default="true" id="1" name="Yellow Highlighter" type="highlight"><engine color="#ffff00" type="TextSelector"><annotation color="#ffffff00" type="Highlight"/></engine><shortcut>1</shortcut></tool>,<tool default="true" id="2" name="Green Highlighter" type="highlight"><engine color="#00ff00" type="TextSelector"><annotation color="#ff00ff00" type="Highlight"/></engine><shortcut>2</shortcut></tool>,<tool id="3" type="underline"><engine color="#ff0000" type="TextSelector"><annotation color="#ffff0000" type="Underline"/></engine><shortcut>3</shortcut></tool>,<tool default="true" id="4" name="Insert Text" type="typewriter"><engine block="true" type="PickPoint"><annotation color="#00ffffff" textColor="#000000" type="Typewriter" width="0"/></engine><shortcut>4</shortcut></tool>,<tool id="5" type="note-inline"><engine block="true" color="#ffff00" hoverIcon="tool-note-inline" type="PickPoint"><annotation color="#ffffff00" textColor="#ff000000" type="FreeText"/></engine><shortcut>5</shortcut></tool>,<tool id="6" type="note-linked"><engine color="#ffff00" hoverIcon="tool-note"><annotation color="#ffffff00" icon="Note" type="Text"/></engine><shortcut>6</shortcut></tool>
      '';
    };
  };

  # Plain-text notes, indexed by the markdown-oxide language server that
  # `development.nix` enables in Neovim.
  home.file.".config/moxide/settings.toml".text = ''
    heading_completions = false
    title_headings = false
    link_filenames_only = true
  '';

  # LaTeX rebuilds preview in the same reader as everything else.
  home.file.".latexmkrc".text = ''
    $pdf_previewer = 'zathura';
    $pdf_update_method = 0;
  '';

  # Plain-text accounting.
  programs.bash.sessionVariables.LEDGER_FILE = "$HOME/documents/personal/finance/main.journal";

  xdg.mimeApps.defaultApplications = {
    "application/pdf" = [ "org.pwmt.zathura.desktop" ];
  };

  home.packages = with pkgs; [
    findDocument
    hledger
    kdePackages.okular
    libreoffice
    pandoc
    zathuraOpenOkular
  ];
}
