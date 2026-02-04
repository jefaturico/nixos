/* Appearance */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }

static const int sloppyfocus               = 0;
static const int bypass_surface_visibility = 0;
static const unsigned int borderpx         = 1;
static const float rootcolor[]             = COLOR(0x222222ff);
static const float bordercolor[]           = COLOR(0x444444ff);
static const float focuscolor[]            = COLOR(0x444444ff);
static const float urgentcolor[]           = COLOR(0xff0000ff);
static const float fullscreen_bg[]         = {0.0f, 0.0f, 0.0f, 1.0f};

/* Tagging - 10 Tags (9 + 1 Browser) */
#define TAGCOUNT (10)

/* Logging */
static int log_level = WLR_ERROR;

static const Rule rules[] = {
	/* app_id     title       tags mask     isfloating   monitor */
	{ "helium",   NULL,       1 << 9,       0,           -1 }, /* Tag 10 */
	{ "zen",      NULL,       1 << 9,       0,           -1 },
};

/* Layouts */
static const Layout layouts[] = {
	{ "[]=",      tile },
	{ "><>",      NULL },
	{ "[M]",      monocle },
};

/* Monitors */
static const MonitorRule monrules[] = {
	{ NULL,       0.6f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,   -1,  -1 },
};

/* Keyboard - Native Colemak-DH ISO/Spanish switching */
static const struct xkb_rule_names xkb_rules = {
	.rules = "",
	.model = "",
	.layout = "us,es",
	.variant = "colemak_dh_iso,",
	.options = "grp:shifts_toggle,caps:ctrl_modifier,compose:menu",
};

static const int repeat_rate = 50;
static const int repeat_delay = 200;

/* Trackpad Configuration */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 1;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.4; /* Matches river-init 0.4 */
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* Mod Key */
#define MODKEY WLR_MODIFIER_LOGO

#define TAGKEYS(KEY,SKEY,TAG) \
	{ MODKEY,                    KEY,            view,            {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,            toggleview,      {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, SKEY,           tag,             {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT,SKEY,toggletag, {.ui = 1 << TAG} }

#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* Commands */
static const char *termcmd[] = { "foot", NULL };
static const char *emacscmd[] = { "emacsclient", "-c", NULL };
static const char *menucmd[] = { "fuzzel", NULL };

static const char *doccmd[] = { "wdoc-find", NULL };
static const char *bgcmd[] = { "wlsetbg", NULL };
static const char *randbgcmd[] = { "wlsetbg", "-r", NULL };

static const Key keys[] = {
	/* Modifier                  Key                  Function          Argument */
	{ MODKEY,                    XKB_KEY_p,           spawn,            {.v = menucmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return,      spawn,            {.v = termcmd} },
	{ MODKEY,                    XKB_KEY_Return,      spawn,            {.v = emacscmd} },

  	{ MODKEY,                    XKB_KEY_d,           spawn,            {.v = doccmd} },    
  	{ MODKEY,                    XKB_KEY_b,           spawn,            {.v = bgcmd} },
  	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_B,           spawn,            {.v = randbgcmd} },
	
	/* Focus Stack (Cycle O/Shift-O) */
	{ MODKEY,                    XKB_KEY_o,           focusstack,       {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_O,           focusstack,       {.i = -1} },

	/* Layout Manipulation */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_plus,           incnmaster,       {.i = +1} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_minus,           incnmaster,       {.i = -1} },
	{ MODKEY,                    XKB_KEY_plus,           setmfact,         {.f = -0.05f} },
	{ MODKEY,                    XKB_KEY_minus,           setmfact,         {.f = +0.05f} },
	{ MODKEY,                    XKB_KEY_space,       zoom,             {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space,       togglefloating,   {0} },
	{ MODKEY,                    XKB_KEY_m,           togglefullscreen, {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_M,           setlayout,        {.v = &layouts[2]} }, /* Monocle */
	{ MODKEY,                    XKB_KEY_t,           setlayout,        {.v = &layouts[0]} }, /* Tile */

	TAGKEYS(          XKB_KEY_1, XKB_KEY_exclam,                     0),
	TAGKEYS(          XKB_KEY_2, XKB_KEY_at,                         1),
	TAGKEYS(          XKB_KEY_3, XKB_KEY_numbersign,                 2),
	TAGKEYS(          XKB_KEY_4, XKB_KEY_dollar,                     3),
	TAGKEYS(          XKB_KEY_5, XKB_KEY_percent,                    4),
	TAGKEYS(          XKB_KEY_6, XKB_KEY_asciicircum,                5),
	TAGKEYS(          XKB_KEY_7, XKB_KEY_ampersand,                  6),
	TAGKEYS(          XKB_KEY_8, XKB_KEY_asterisk,                   7),
	TAGKEYS(          XKB_KEY_9, XKB_KEY_parenleft,                  8),
	TAGKEYS(          XKB_KEY_0, XKB_KEY_parenright,                 9),

    
	{ MODKEY,                    XKB_KEY_comma,       focusmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,                    XKB_KEY_period,      focusmon,         {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_less,        tagmon,           {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_greater,     tagmon,           {.i = WLR_DIRECTION_RIGHT} },

	/* Quit/Kill */
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_C,           killclient,       {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Escape,           quit,             {0} },

    /* Media Keys */
    { 0, XKB_KEY_XF86AudioRaiseVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%+") },
    { 0, XKB_KEY_XF86AudioLowerVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-") },
    { 0, XKB_KEY_XF86AudioMute,        spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
    { 0, XKB_KEY_XF86MonBrightnessUp,  spawn, SHCMD("brightnessctl set +10%") },
    { 0, XKB_KEY_XF86MonBrightnessDown,spawn, SHCMD("brightnessctl set 10%-") },
};

static const Button buttons[] = {
	{ MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
};
