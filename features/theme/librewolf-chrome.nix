# LibreWolf browser chrome, styled from the active Tinty palette.
#
# This is not a Nix expression that evaluates to configuration: it is the
# literal body of a shell heredoc written by `apply-desktop-theme`, so every
# ''${base00}-style reference is expanded by that script when a theme is
# applied, not by Nix. It lives in its own file because 400 lines of CSS
# otherwise dominate the module that generates it.
#
# Color-token coverage adapted from FoxOne 3.5.1 (MIT). The palette and the
# transparent layout are local to this configuration.
#
# Interpolated at six-space indentation so the surrounding indented string
# keeps its base indent; keep the body itself at column zero.
''
  :root {
    /* Color-token coverage adapted from FoxOne 3.5.1 (MIT).
       The palette and transparent layout remain local to this config. */
    --uc-color-base: #''${base00}b3 !important;
    --uc-color-surface: #''${base01}b3 !important;
    --uc-color-surface-focus: #''${base02}cc !important;
    --uc-color-hover: #''${base02}99 !important;
    --uc-color-active: #''${base03}99 !important;
    --uc-color-popup: #''${base00}e6 !important;
    --uc-color-text: #''${base05} !important;
    --uc-color-text-strong: #''${base06} !important;
    --uc-color-accent: #''${base0d} !important;

    /* Legacy lightweight-theme tokens. */
    --toolbar-bgcolor: transparent !important;
    --toolbar-color: #''${base05} !important;
    --toolbar-field-background-color: #''${base01}b3 !important;
    --toolbar-field-color: #''${base05} !important;
    --toolbar-field-focus-background-color: #''${base02}cc !important;
    --toolbar-field-focus-color: #''${base06} !important;
    --lwt-accent-color: #''${base00}b3 !important;
    --lwt-text-color: #''${base05} !important;
    --lwt-selected-tab-background-color: #''${base02}b3 !important;
    --arrowpanel-background: #''${base00}e6 !important;
    --arrowpanel-color: #''${base05} !important;
    --arrowpanel-border-color: #''${base02} !important;
    --button-hover-bgcolor: #''${base02}99 !important;
    --button-active-bgcolor: #''${base03}99 !important;
    --focus-outline-color: #''${base0d} !important;
    --tab-selected-textcolor: #''${base06} !important;
    --tab-hover-background-color: #''${base01}99 !important;
    --urlbar-box-bgcolor: #''${base01}b3 !important;
    --urlbar-box-hover-bgcolor: #''${base02}b3 !important;
    --urlbarView-highlight-background: #''${base02}cc !important;
    --urlbarView-highlight-color: #''${base06} !important;
    --sidebar-background-color: transparent !important;
    --sidebar-text-color: #''${base05} !important;
    --sidebar-border-color: #''${base02}99 !important;

    /* Firefox Nova semantic tokens. These also cross the shadow-DOM
       boundary used by moz-button controls in the address bar. */
    --toolbar-background-color: transparent !important;
    --toolbox-background-color: transparent !important;
    --toolbar-text-color: #''${base05} !important;
    --toolbar-field-text-color: #''${base05} !important;
    --toolbar-field-text-color-focus: #''${base06} !important;
    --panel-background-color: #''${base00}e6 !important;
    --panel-text-color: #''${base05} !important;
    --panel-border-color: #''${base02}99 !important;
    --panel-separator-color: #''${base02}99 !important;
    --button-background-color: #''${base01}b3 !important;
    --button-background-color-hover: #''${base02}99 !important;
    --button-background-color-active: #''${base03}99 !important;
    --button-background-color-ghost: transparent !important;
    --button-background-color-ghost-hover: #''${base02}99 !important;
    --button-background-color-ghost-active: #''${base03}99 !important;
    --button-text-color: #''${base05} !important;
    --button-text-color-hover: #''${base06} !important;
    --button-text-color-active: #''${base06} !important;
    --color-accent-primary: #''${base0d} !important;
    --color-accent-primary-hover: #''${base0c} !important;
    --color-accent-primary-active: #''${base0d} !important;
    --color-accent-primary-contrast: #''${base00} !important;
    --tabpanel-background-color: #''${base00} !important;
  }

  #main-window {
    background: #''${base00}b3 !important;
    background-color: #''${base00}b3 !important;
    color: #''${base05} !important;
  }

  body,
  #titlebar,
  #TabsToolbar,
  #nav-bar,
  #PersonalToolbar,
  #navigator-toolbox,
  #sidebar-box,
  #sidebar-main,
  #sidebar,
  #sidebar-header,
  #sidebar-panel-header,
  .sidebar-panel,
  .sidebar-placesTree,
  #vertical-tabs,
  #vertical-tabs-pane,
  #vertical-pinned-tabs-container,
  #tabbrowser-tabs[orient="vertical"],
  #tabbrowser-tabs[orient="vertical"] #tabbrowser-arrowscrollbox {
    background: transparent !important;
    background-color: transparent !important;
    color: #''${base05} !important;
  }

  /* =========================================================================
     Focus Mode Toggle (Keybind: Ctrl+Shift+B)
     ========================================================================= */

  /* Focus Mode (When PersonalToolbar is collapsed): Collapsible top chrome that auto-hides */
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])) {
    --toolbar-field-background-color: #''${base01}b3 !important;
    --toolbar-field-focus-background-color: #''${base02}cc !important;
    --toolbar-field-color: #''${base05} !important;
    --toolbar-field-focus-color: #''${base06} !important;
    background: transparent !important;
    background-color: transparent !important;
    color: #''${base05} !important;
    margin-top: calc(-1 * (var(--tab-min-height, 32px) + var(--urlbar-toolbar-height, 36px))) !important;
    opacity: 0 !important;
    pointer-events: none !important;
    transition: margin-top 220ms cubic-bezier(0.2, 0, 0, 1),
                opacity 200ms ease !important;
  }

  /* In Focus Mode, reveal when toolbox receives focus (Ctrl+L, Ctrl+T, F6) */
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):focus-within {
    margin-top: 0px !important;
    opacity: 1 !important;
    pointer-events: auto !important;
  }

  /* Standard Mode (When PersonalToolbar is toggled ON with Ctrl+Shift+B): Permanently visible toolbar */
  #navigator-toolbox:has(#PersonalToolbar:not([collapsed="true"]):not([collapsed=""])),
  :root[customizing] #navigator-toolbox {
    --toolbar-field-background-color: #''${base01}b3 !important;
    --toolbar-field-focus-background-color: #''${base02}cc !important;
    --toolbar-field-color: #''${base05} !important;
    --toolbar-field-focus-color: #''${base06} !important;
    background: transparent !important;
    background-color: transparent !important;
    color: #''${base05} !important;
    margin-top: 0px !important;
    opacity: 1 !important;
    pointer-events: auto !important;
  }

  /* Keep the physical bookmarks bar strip zero-height so Ctrl+Shift+B acts purely as a mode toggle */
  #PersonalToolbar {
    max-height: 0px !important;
    min-height: 0px !important;
    overflow: hidden !important;
    padding: 0 !important;
    margin: 0 !important;
  }

  .urlbar,
  #urlbar,
  #searchbar {
    --urlbar-background-color: #''${base01}b3 !important;
    --urlbar-background-color-focus: #''${base02}cc !important;
    --toolbar-field-border-color: transparent !important;
    --toolbar-field-border-color-focus: #''${base0d}99 !important;
    --button-background-color: transparent !important;
    --button-background-color-hover: #''${base02}99 !important;
    --button-background-color-active: #''${base03}99 !important;
    --button-background-color-ghost: transparent !important;
    --button-background-color-ghost-hover: #''${base02}99 !important;
    --button-background-color-ghost-active: #''${base03}99 !important;
    --button-text-color: #''${base05} !important;
    --button-text-color-hover: #''${base06} !important;
    color: #''${base05} !important;
  }

  .tabbrowser-tab .tab-background {
    background: transparent !important;
    border: none !important;
    box-shadow: none !important;
    border-radius: 9px !important;
  }

  .tabbrowser-tab:hover .tab-background {
    background-color: #''${base01}99 !important;
  }

  .tabbrowser-tab[selected] .tab-background,
  .tabbrowser-tab[multiselected] .tab-background {
    background-color: #''${base02}b3 !important;
    background-image: none !important;
    outline: none !important;
  }

  .tabbrowser-tab[selected] .tab-label {
    color: #''${base06} !important;
  }

  #urlbar-background,
  .urlbar-background,
  #searchbar,
  .urlbar:not([focused], [open]) > .urlbar-background {
    appearance: none !important;
    background: #''${base01}b3 !important;
    background-color: #''${base01}b3 !important;
    background-image: none !important;
    border: none !important;
    border-radius: 9px !important;
    box-shadow: none !important;
    outline: none !important;
  }

  #urlbar[focused] > #urlbar-background,
  #urlbar[focused="true"] > #urlbar-background,
  #urlbar[open] > #urlbar-background,
  #urlbar:focus-within > #urlbar-background,
  .urlbar:is([focused], [open]) > .urlbar-background,
  .urlbar:focus-within > .urlbar-background {
    background: #''${base02}cc !important;
    background-color: #''${base02}cc !important;
    background-image: none !important;
    border: none !important;
    border-radius: 9px !important;
    box-shadow: 0 0 0 1px #''${base0d}99 !important;
  }

  .urlbar-input-container,
  moz-input-box.urlbar-input-box,
  .urlbar-input {
    background: transparent !important;
    background-color: transparent !important;
    background-image: none !important;
    color: #''${base05} !important;
  }

  #urlbar-searchmode-switcher,
  #searchmode-switcher-chicklet,
  .searchmode-switcher,
  .searchmode-switcher-content {
    --button-background-color: transparent !important;
    --button-background-color-hover: #''${base02}99 !important;
    --button-background-color-active: #''${base03}99 !important;
    --button-background-color-ghost: transparent !important;
    --button-background-color-ghost-hover: #''${base02}99 !important;
    --button-background-color-ghost-active: #''${base03}99 !important;
    --button-text-color: #''${base05} !important;
    --button-text-color-hover: #''${base06} !important;
    background: transparent !important;
    background-color: transparent !important;
    color: #''${base05} !important;
  }

  #urlbar-searchmode-switcher::part(button),
  #searchmode-switcher-chicklet::part(button),
  .searchmode-switcher::part(button) {
    background: transparent !important;
    background-color: transparent !important;
    color: #''${base05} !important;
    border: none !important;
    border-radius: 9px !important;
    box-shadow: none !important;
  }

  #urlbar-searchmode-switcher:hover::part(button),
  #urlbar-searchmode-switcher[open]::part(button),
  #searchmode-switcher-chicklet:hover::part(button),
  #searchmode-switcher-chicklet[open]::part(button),
  .searchmode-switcher:hover::part(button),
  .searchmode-switcher[open]::part(button) {
    background: #''${base02}cc !important;
    background-color: #''${base02}cc !important;
    color: #''${base06} !important;
  }

  .searchmode-switcher-dropmarker,
  .searchmode-switcher-icon {
    color: #''${base05} !important;
    fill: currentColor !important;
  }

  .urlbarView,
  .urlbarView-body-inner,
  #urlbar-results {
    display: none !important;
  }

  toolbarbutton,
  .toolbarbutton-1 {
    border-radius: 9px !important;
  }

  toolbarbutton:hover,
  .toolbarbutton-1:hover > .toolbarbutton-icon,
  .toolbarbutton-1:hover > .toolbarbutton-text,
  .toolbarbutton-1:hover > .toolbarbutton-badge-stack {
    background-color: #''${base02}99 !important;
  }

  toolbarbutton[open],
  toolbarbutton:active,
  .toolbarbutton-1:active > .toolbarbutton-icon {
    background-color: #''${base03}99 !important;
  }

  menupopup,
  panel,
  panelmultiview,
  .panel-subview-body,
  #downloadsPanel-mainView,
  #unified-extensions-view,
  findbar,
  notification-message {
    appearance: none !important;
    background: #''${base00}e6 !important;
    background-color: #''${base00}e6 !important;
    color: #''${base05} !important;
    border-color: #''${base02}99 !important;
    border-radius: 9px !important;
    box-shadow: none !important;
  }

  menuitem,
  .subviewbutton,
  .unified-extensions-item {
    border-radius: 9px !important;
  }

  menuitem:hover,
  .subviewbutton:hover,
  .unified-extensions-item:hover {
    background-color: #''${base02}cc !important;
    color: #''${base06} !important;
  }

  toolbarseparator,
  menuseparator,
  .panel-separator,
  #sidebar-splitter,
  #sidebar-launcher-splitter {
    border-color: #''${base02}99 !important;
    background-color: transparent !important;
  }

  #identity-icon-box,
  #tracking-protection-icon-container,
  #page-action-buttons {
    background-color: transparent !important;
    color: #''${base05} !important;
  }

  #browser,
  #appcontent,
  #tabbrowser-tabbox,
  #tabbrowser-tabpanels {
    background: transparent !important;
    background-color: transparent !important;
    height: 100% !important;
  }

  /* Content separation: concentric 7px rounded island (15px outer - 8px margin) */
  #tabbrowser-tabpanels .browserSidebarContainer,
  #tabbrowser-tabpanels > .deck-selected,
  #tabbrowser-tabpanels > vbox {
    background-color: #''${base00} !important;
    border-radius: 7px !important;
    overflow: hidden !important;
    margin: 0 8px 8px 8px !important;
    box-shadow: none !important;
    transition: margin 220ms cubic-bezier(0.2, 0, 0, 1),
                border-radius 220ms cubic-bezier(0.2, 0, 0, 1) !important;
  }

  .browserSidebarContainer,
  browser[type="content-primary"],
  browser[type="content"] {
    background-color: #''${base00} !important;
    border-radius: 7px !important;
    overflow: hidden !important;
    transition: border-radius 220ms cubic-bezier(0.2, 0, 0, 1) !important;
  }

  /* In Focus Mode (PersonalToolbar collapsed) when UI is idle: Expand content edge-to-edge */
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):not(:focus-within) ~ #browser #tabbrowser-tabpanels .browserSidebarContainer,
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):not(:focus-within) ~ #browser #tabbrowser-tabpanels > .deck-selected,
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):not(:focus-within) ~ #browser #tabbrowser-tabpanels > vbox,
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):not(:focus-within) ~ #browser .browserSidebarContainer,
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):not(:focus-within) ~ #browser browser[type="content-primary"],
  #navigator-toolbox:has(#PersonalToolbar:is([collapsed="true"], [collapsed=""])):not(:focus-within) ~ #browser browser[type="content"] {
    margin: 0 !important;
    border-radius: 0 !important;
    box-shadow: none !important;
  }

  /* Fullscreen expansion resets margins and rounding. */
  :root[inFullscreen] #tabbrowser-tabpanels .browserSidebarContainer,
  :root[inFullscreen] #tabbrowser-tabpanels > .deck-selected,
  :root[inFullscreen] #tabbrowser-tabpanels > vbox,
  :root[inDOMFullscreen] #tabbrowser-tabpanels .browserSidebarContainer,
  :root[inDOMFullscreen] #tabbrowser-tabpanels > .deck-selected,
  :root[inDOMFullscreen] #tabbrowser-tabpanels > vbox,
  #main-window[inFullscreen] #tabbrowser-tabpanels .browserSidebarContainer,
  #main-window[inDOMFullscreen] #tabbrowser-tabpanels .browserSidebarContainer {
    margin: 0 !important;
    border-radius: 0 !important;
    box-shadow: none !important;
  }

  /* Resist-Fingerprinting Letterboxing support. */
  .letterboxing {
    --letterboxing-bgcolor: #''${base00} !important;
    --letterboxing-border-radius: 7px !important;
  }

  .letterboxing .browserContainer {
    background-color: #''${base00} !important;
  }

  /* Hide statuspanel hover link URL preview box at bottom left */
  #statuspanel,
  #statuspanel-label,
  #statuspanel[type="overLink"] {
    display: none !important;
    opacity: 0 !important;
    pointer-events: none !important;
  }

  /* Hide all scrollbars across the browser */
  :root,
  #main-window,
  #browser,
  #tabbrowser-tabpanels,
  scrollbox,
  scrollbar,
  scrollbar * {
    scrollbar-width: none !important;
  }

  scrollbar {
    display: none !important;
    visibility: collapse !important;
  }''
