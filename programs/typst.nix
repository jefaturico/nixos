{ ... }:

# Typst: the compiler, its language server, and the live preview.
{
  home-manager.users.jefaturico =
    { pkgs, ... }:

    # Typst documents: written in Neovim, watched in a browser window.
    #
    # The preview is a browser page rather than the PDF reader next door, and
    # that is not a preference. Sioyek can only show a file that exists, so
    # every refresh costs a full compile to PDF, a write to disk and a reload,
    # and the earliest it can happen is the next `:write`. Tinymist renders the
    # buffer as it is being typed -- unsaved, incrementally, only the vectors
    # that changed -- and pushes them down a websocket to a page that is already
    # open. It is the difference between seeing a paragraph land and asking to
    # see it. Sioyek stays what it is: the reader for documents that are done.
    #
    # Clicking the preview jumps the editor to the source that drew what was
    # clicked, and it needs nothing here to do so: tinymist sends a plain
    # `window/showDocument` unless a client asks for its custom notification
    # instead, and Neovim has handled that request since 0.8.
    let
      tinymist = "${pkgs.tinymist}/bin/tinymist";
      typst = "${pkgs.typst}/bin/typst";

      # An app window has no tab strip, no address bar and no history: the
      # preview is a document being looked at, not a page being browsed, and
      # niri gives it a column of its own like any other window.
      browser = "${pkgs.brave}/bin/brave";
    in
    {
      # Typst itself is here for the things an editor is the wrong place for --
      # `typst watch`, `typst fonts`, compiling from a script. Tinymist carries
      # its own copy of the compiler, so this is not what the preview uses.
      home.packages = [ pkgs.typst ];

      # The first language server in this configuration, and the reason is that
      # Typst's surface is not guessable the way a shell script's is: which of
      # `#figure`'s arguments exist, what `#set page` accepts, whether a label is
      # defined anywhere. Completion and diagnostics answer that in the buffer,
      # and tinymist is also the formatter (typstyle, built in) and the preview
      # server, so one binary covers all three.
      #
      # No plugin is involved. Neovim 0.11 resolves servers from `vim.lsp.config`
      # and binds the LSP keys itself: `K` hover, `grn` rename, `gra` code
      # action, `grr` references, and `gq` format through the `formatexpr` it
      # sets when the server offers formatting.
      programs.neovim.initLua = ''
        vim.lsp.config.tinymist = {
          cmd = { "${tinymist}" },
          filetypes = { "typst" },
          -- A document is a project, not a file: `#import "template.typ"` and
          -- `#image("figures/x.png")` resolve against the root, so the server
          -- has to be told where that is or it answers for the wrong tree.
          root_markers = { "typst.toml", ".git" },
          settings = {
            formatterMode = "typstyle",
            formatterPrintWidth = 80,
          },
        }
        vim.lsp.enable("tinymist")

        local typst_group = vim.api.nvim_create_augroup("jf-typst", { clear = true })

        -- The preview belongs to the language server session, which is what
        -- makes it live: the server already has the unsaved buffer, so nothing
        -- is compiled twice and nothing waits for a write. It also means the
        -- preview dies with the editor, which is the right lifetime for it.
        local preview_url = {}

        local function typst_client(buf)
          return vim.lsp.get_clients({ bufnr = buf, name = "tinymist" })[1]
        end

        local function open_preview()
          local client = typst_client(0)
          if not client then
            vim.notify("tinymist is not attached to this buffer", vim.log.levels.WARN)
            return
          end

          -- A second press is not a second preview. The server keeps serving the
          -- same address, so this reopens the window that was closed rather than
          -- starting anything.
          local url = preview_url[client.id]
          if url then
            vim.system({ "${browser}", "--app=" .. url }, { detach = true })
            return
          end

          client:exec_cmd(
            { command = "tinymist.startDefaultPreview", arguments = {} },
            { bufnr = 0 },
            function(err, res)
              if err or not res or not res.staticServerAddr then
                vim.notify("preview failed to start: " .. vim.inspect(err), vim.log.levels.ERROR)
                return
              end
              preview_url[client.id] = "http://" .. res.staticServerAddr
              vim.system({ "${browser}", "--app=" .. preview_url[client.id] }, { detach = true })
            end
          )
        end

        -- The other direction of the jump the preview already does by itself:
        -- the page follows the cursor, so moving through the source scrolls the
        -- rendering to the same place. On CursorHold rather than CursorMoved
        -- because `updatetime` is 250ms and a scroll per keystroke would be
        -- both wasted work and a page that never sits still.
        vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
          group = typst_group,
          pattern = "*.typ",
          callback = function(args)
            local client = typst_client(args.buf)
            if not client or not preview_url[client.id] then
              return
            end
            local pos = vim.api.nvim_win_get_cursor(0)
            client:exec_cmd({
              command = "tinymist.scrollPreview",
              arguments = {
                "default_preview",
                {
                  event = "panelScrollTo",
                  filepath = vim.api.nvim_buf_get_name(args.buf),
                  line = pos[1] - 1,
                  character = pos[2],
                },
              },
            }, { bufnr = args.buf })
          end,
        })

        -- Compiling is a separate act from previewing: the PDF is what gets
        -- sent to someone, and it is wanted at the end rather than continuously.
        -- The buffer is written first because the compiler reads the file, not
        -- the editor's copy of it.
        local function typst_compile()
          if vim.bo.modified then
            vim.cmd.write()
          end
          local file = vim.api.nvim_buf_get_name(0)
          vim.system(
            { "${typst}", "compile", file },
            { text = true },
            vim.schedule_wrap(function(out)
              if out.code == 0 then
                vim.notify(vim.fn.fnamemodify(file, ":t:r") .. ".pdf")
              else
                vim.notify(out.stderr, vim.log.levels.ERROR)
              end
            end)
          )
        end

        -- Buffer-local, and set from an autocommand rather than at the top of
        -- this file, so that they exist only where they mean something -- and so
        -- that <leader> is already the space bar by the time they are read.
        vim.api.nvim_create_autocmd("FileType", {
          group = typst_group,
          pattern = "typst",
          callback = function(args)
            vim.keymap.set("n", "<leader>p", open_preview, {
              buffer = args.buf,
              desc = "Preview document",
            })
            vim.keymap.set("n", "<leader>c", typst_compile, {
              buffer = args.buf,
              desc = "Compile document to PDF",
            })
          end,
        })
      '';

      # The same three things for Emacs -- server, preview, compile -- contributed
      # from here rather than from features/emacs for the same reason the Neovim
      # block above lives here: the tool belongs to the documents it is for.
      #
      # Three packages, and the reasoning for each:
      #
      #   typst-ts-mode   Syntax highlighting. Emacs has no Typst mode built in,
      #                   and this is the only one packaged in nixpkgs. It is
      #                   tree-sitter based, so it needs the grammar below --
      #                   Emacs will not fetch or compile one on demand.
      #   typst-preview   The live browser preview. This could be done without a
      #                   package, the way the Neovim block above does it, by
      #                   calling tinymist's `startDefaultPreview' over
      #                   `eglot-execute-command' -- but that is forty lines of
      #                   websocket and scroll-sync plumbing to maintain in place
      #                   of a package that is doing the same thing and is kept
      #                   current.
      #   the grammar     Required by typst-ts-mode, as above.
      #
      # Not a package: the language server. Eglot is built into Emacs 29+, so
      # tinymist is wired up with a `setq' rather than lsp-mode and its dependency
      # tree.
      programs.emacs.extraPackages = epkgs: [
        epkgs.typst-ts-mode
        epkgs.typst-preview
        (epkgs.treesit-grammars.with-grammars (grammars: [ grammars.tree-sitter-typst ]))
      ];

      programs.emacs.extraConfig = ''
        ;;; Typst ---------------------------------------------------------------

        (add-to-list 'auto-mode-alist '("\\.typ\\'" . typst-ts-mode))

        (with-eval-after-load 'eglot
          (add-to-list 'eglot-server-programs
                       '(typst-ts-mode . ("${tinymist}"))))

        ;; The same "a document is a project, not a file" problem the Neovim
        ;; configuration above solves with `root_markers'. Eglot takes its root
        ;; from project.el, which only knows about version control, so `typst.toml'
        ;; has to be named as a root marker or the server answers for the wrong
        ;; tree -- `#import "template.typ"' and `#image("figures/x.png")' resolve
        ;; against the root, not against the file.
        (with-eval-after-load 'project
          (add-to-list 'project-vc-extra-root-markers "typst.toml"))

        (defun nixos-typst--setup ()
          ;; typstyle, reached through the server rather than run separately, so
          ;; `eglot-format-buffer' is the formatter and there is no second
          ;; process to keep in step.
          (setq-local eglot-workspace-configuration
                      '(:formatterMode "typstyle" :formatterPrintWidth 80))
          (eglot-ensure))

        (add-hook 'typst-ts-mode-hook #'nixos-typst--setup)

        ;; Compiling is a separate act from previewing: the PDF is the thing that
        ;; gets sent to someone, wanted at the end rather than continuously.
        (with-eval-after-load 'typst-ts-mode
          (setq typst-ts-compile-executable-location "${typst}"))

        ;; A preview is a document being looked at, not a page being browsed, so
        ;; it gets an app window with no tab strip or address bar, exactly as the
        ;; Neovim side opens it. The binding is scoped to the two commands that
        ;; open a browser rather than overriding what `browse-url' means
        ;; everywhere else.
        (defun nixos-typst--browse-app (url &rest _)
          (start-process "typst-preview" nil "${browser}" (concat "--app=" url)))

        ;; typst-preview asks which file is the document's master with an
        ;; unconditional `read-file-name' the first time a buffer is previewed --
        ;; `typst-preview-ask-if-pin-main' only suppresses the *second* question,
        ;; about writing the answer into the file as a local variable. For a
        ;; single-file document the answer is always the file itself, so it is
        ;; given here rather than typed every time. A multi-file document still
        ;; overrides it the intended way, with a `typst-preview--master-file'
        ;; file-local variable, which this leaves alone.
        (defun nixos-typst--default-master (&rest _)
          (when (and buffer-file-name (not typst-preview--master-file))
            (setq-local typst-preview--master-file (file-truename buffer-file-name))))

        (defun nixos-typst--with-app-window (fn &rest args)
          (let ((browse-url-browser-function #'nixos-typst--browse-app))
            (apply fn args)))

        (with-eval-after-load 'typst-preview
          (setq typst-preview-executable "${tinymist}"
                typst-preview-browser "default"
                typst-preview-autostart t
                typst-preview-open-browser-automatically t
                ;; Asking to pin a main file writes a file-local variable into the
                ;; document being written, which is not something a preview should
                ;; do on its own.
                typst-preview-ask-if-pin-main nil)
          (advice-add 'typst-preview-start :before #'nixos-typst--default-master)
          (advice-add 'typst-preview-start :around #'nixos-typst--with-app-window)
          (advice-add 'typst-preview-open-browser :around
                      #'nixos-typst--with-app-window))

        (with-eval-after-load 'typst-ts-mode
          (keymap-set typst-ts-mode-map "C-c C-c" #'typst-ts-compile)
          (keymap-set typst-ts-mode-map "C-c C-v" #'typst-preview-mode)
          (keymap-set typst-ts-mode-map "C-c C-f" #'eglot-format-buffer))
      '';
    };
}
