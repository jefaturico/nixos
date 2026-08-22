{ pkgs }:

pkgs.writeShellApplication {
  name = "movement-reminder";
  runtimeInputs = with pkgs; [
    coreutils
    gnugrep
    jq
    libnotify
    niri
    playerctl
    procps
    python3
    swayidle
  ];
  text = ''
    exec python3 -u - "$@" << 'PYEOF'
    import asyncio
    import enum
    import json
    import os
    import subprocess
    import sys
    import time
    import unittest

    is_self_test = "--self-test" in sys.argv
    is_test_mode = "--test" in sys.argv or os.getenv("MOVEMENT_TEST") == "1"
    debug_logging = (is_test_mode and not is_self_test) or os.getenv("MOVEMENT_DEBUG") == "1" or "-v" in sys.argv

    if is_test_mode:
        POSTURE_INTERVAL = int(os.getenv("MOVEMENT_POSTURE_INTERVAL", 5))
        BREAK_INTERVAL = int(os.getenv("MOVEMENT_BREAK_INTERVAL", 10))
        POSTURE_NOTIFICATION_DURATION_MS = int(os.getenv("MOVEMENT_POSTURE_DURATION_MS", 3000))
        BREAK_NOTIFICATION_DURATION_MS = int(os.getenv("MOVEMENT_BREAK_DURATION_MS", 5000))
        QUALIFYING_BREAK_IDLE = int(os.getenv("MOVEMENT_QUALIFYING_BREAK_IDLE", 4))
        OVERDUE_REMINDER_INTERVAL = int(os.getenv("MOVEMENT_OVERDUE_REMINDER_INTERVAL", 5))
        IDLE_DETECTION_TIMEOUT = int(os.getenv("MOVEMENT_IDLE_TIMEOUT", 2))
        POST_IMMERSION_GRACE_PERIOD = int(os.getenv("MOVEMENT_GRACE_PERIOD", 2))
        IMMERSION_POLL_INTERVAL = 1
    else:
        POSTURE_INTERVAL = int(os.getenv("MOVEMENT_POSTURE_INTERVAL", 25 * 60))
        BREAK_INTERVAL = int(os.getenv("MOVEMENT_BREAK_INTERVAL", 50 * 60))
        POSTURE_NOTIFICATION_DURATION_MS = int(os.getenv("MOVEMENT_POSTURE_DURATION_MS", 5000))
        BREAK_NOTIFICATION_DURATION_MS = int(os.getenv("MOVEMENT_BREAK_DURATION_MS", 10000))
        QUALIFYING_BREAK_IDLE = int(os.getenv("MOVEMENT_QUALIFYING_BREAK_IDLE", 5 * 60))
        OVERDUE_REMINDER_INTERVAL = int(os.getenv("MOVEMENT_OVERDUE_REMINDER_INTERVAL", 5 * 60))
        IDLE_DETECTION_TIMEOUT = int(os.getenv("MOVEMENT_IDLE_TIMEOUT", 90))
        POST_IMMERSION_GRACE_PERIOD = int(os.getenv("MOVEMENT_GRACE_PERIOD", 8))
        IMMERSION_POLL_INTERVAL = 3


    def log(msg: str):
        if debug_logging:
            print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


    class State(enum.Enum):
        ACTIVE = "ACTIVE"
        BREAK_DUE = "BREAK_DUE"
        IDLE_ORDINARY = "IDLE_ORDINARY"
        IDLE_DURING_BREAK = "IDLE_DURING_BREAK"
        BREAK_COMPLETED = "BREAK_COMPLETED"


    def parse_mpris_players_status(raw_output: str) -> dict:
        """Parses 'playerctl -a status -f {{playerName}}\t{{status}}' into a dictionary."""
        players = {}
        if not raw_output:
            return players
        for line in raw_output.strip().splitlines():
            parts = line.split("\t", 1)
            if len(parts) == 2:
                players[parts[0].strip().lower()] = parts[1].strip().lower()
        return players


    def is_player_playing_for_app(app_id: str, mpris_players_dict: dict) -> bool:
        """Correlates a focused window app_id with active MPRIS player identities."""
        app = app_id.lower()
        for player, status in mpris_players_dict.items():
            if status == "playing":
                if (
                    app in player
                    or player.startswith(app)
                    or ("firefox" in app and "firefox" in player)
                    or ("librewolf" in app and "librewolf" in player)
                    or ("brave" in app and "brave" in player)
                    or ("chromium" in app and "chromium" in player)
                    or ("chrome" in app and "chrome" in player)
                    or ("mpv" in app and "mpv" in player)
                    or ("stremio" in app and "stremio" in player)
                    or ("vlc" in app and "vlc" in player)
                ):
                    return True
        return False


    def evaluate_immersive_heuristics(
        windows_data,
        mpris_output: str = "",
        is_locked: bool = False,
        custom_game_ids: list = None,
    ) -> bool:
        """
        Determines immersion based on correlated signals:
        1. Screen is locked.
        2. Focused window is fullscreen AND is an active game.
        3. Focused window is fullscreen AND belongs to a media player/browser that is actively 'Playing'.
        """
        if is_locked:
            return True

        if not windows_data:
            return False

        game_patterns = [
            "steam_app_", "gamescope", "lutris", "heroic", "wine", "proton",
            "retroarch", "dolphin-emu", "rpcs3", "pcsx2", "yuzu", "ryujinx",
            "citra", "osu!", "minecraft", "steam"
        ]
        if custom_game_ids:
            game_patterns.extend([g.strip().lower() for g in custom_game_ids if g.strip()])

        try:
            windows = json.loads(windows_data) if isinstance(windows_data, str) else windows_data
            for w in windows:
                if w.get("is_focused") and w.get("is_fullscreen"):
                    app_id = (w.get("app_id") or "").lower()
                    title = (w.get("title") or "").lower()

                    # 1. Games (focused + fullscreen)
                    if any(g in app_id or g in title for g in game_patterns):
                        return True

                    # 2. Media players & browsers (focused + fullscreen + specific player is actively Playing)
                    media_apps = [
                        "mpv", "com.stremio.stremio", "stremio", "vlc",
                        "firefox", "librewolf", "brave", "chromium", "chrome"
                    ]
                    if any(m in app_id for m in media_apps):
                        mpris_dict = parse_mpris_players_status(mpris_output)
                        if is_player_playing_for_app(app_id, mpris_dict):
                            return True
        except Exception:
            pass

        return False


    class MovementReminder:
        def __init__(
            self,
            posture_interval=None,
            break_interval=None,
            qualifying_break_idle=None,
            overdue_reminder_interval=None,
            idle_detection_timeout=None,
            post_immersion_grace_period=None,
            immersion_poll_interval=None,
            now_fn=None,
            notify_fn=None,
            is_immersive_fn=None,
        ):
            self.posture_interval = posture_interval if posture_interval is not None else POSTURE_INTERVAL
            self.break_interval = break_interval if break_interval is not None else BREAK_INTERVAL
            self.qualifying_break_idle = qualifying_break_idle if qualifying_break_idle is not None else QUALIFYING_BREAK_IDLE
            self.overdue_reminder_interval = overdue_reminder_interval if overdue_reminder_interval is not None else OVERDUE_REMINDER_INTERVAL
            self.idle_detection_timeout = idle_detection_timeout if idle_detection_timeout is not None else IDLE_DETECTION_TIMEOUT
            self.post_immersion_grace_period = post_immersion_grace_period if post_immersion_grace_period is not None else POST_IMMERSION_GRACE_PERIOD
            self.immersion_poll_interval = immersion_poll_interval if immersion_poll_interval is not None else IMMERSION_POLL_INTERVAL

            self.now_fn = now_fn or time.monotonic
            self.custom_notify = notify_fn
            self.custom_immersive = is_immersive_fn

            self.state = State.ACTIVE
            self.is_immersive_active = False
            self.immersion_exit_time = 0.0
            self.pending_post_immersion_break = False

            self.accumulated_active_time = 0.0
            self.posture_shown = False
            self.last_overdue_notify_time = 0.0
            self.last_immersion_poll_time = 0.0
            self.idle_start_time = 0.0
            self.last_tick_time = self.now_fn()
            self.swayidle_proc = None
            self.notifications_log = []

            # Configurable extra games from env
            extra_games = os.getenv("MOVEMENT_GAME_APP_IDS", "")
            self.custom_game_ids = [g.strip() for g in extra_games.split(",") if g.strip()]

            log(f"Initialized daemon (test_mode={is_test_mode}, posture={self.posture_interval}s, break={self.break_interval}s, qualifying_idle={self.qualifying_break_idle}s)")

        def set_state(self, new_state: State, reason: str = ""):
            if self.state != new_state:
                log(f"STATE CHANGE: {self.state.value} -> {new_state.value} ({reason})")
                self.state = new_state

        def check_system_immersion(self) -> bool:
            """Query live system state with targeted, throttled checks."""
            if self.custom_immersive is not None:
                return self.custom_immersive()

            # 1. Screen lock check (explicit binary list)
            is_locked = False
            for locker in ("hyprlock", "swaylock", "waylock", "gtklock"):
                try:
                    if subprocess.run(["pgrep", "-x", locker],
                                      stdout=subprocess.DEVNULL,
                                      stderr=subprocess.DEVNULL).returncode == 0:
                        is_locked = True
                        break
                except Exception:
                    pass
            if is_locked:
                return True

            # 2. Query Niri windows
            windows_data = []
            focused_media_candidate = False
            try:
                res = subprocess.run(["niri", "msg", "--json", "windows"],
                                     capture_output=True, text=True, timeout=1)
                if res.returncode == 0:
                    windows_data = res.stdout
                    windows = json.loads(windows_data)
                    for w in windows:
                        if w.get("is_focused") and w.get("is_fullscreen"):
                            app = (w.get("app_id") or "").lower()
                            if any(m in app for m in ("mpv", "stremio", "vlc", "firefox", "librewolf", "brave", "chromium", "chrome")):
                                focused_media_candidate = True
                                break
            except Exception:
                pass

            # 3. Query MPRIS only if a focused fullscreen candidate exists
            mpris_output = ""
            if focused_media_candidate:
                try:
                    res = subprocess.run(["playerctl", "-a", "status", "-f", "{{playerName}}\t{{status}}"],
                                         capture_output=True, text=True, timeout=1)
                    if res.returncode == 0:
                        mpris_output = res.stdout
                except Exception:
                    pass

            return evaluate_immersive_heuristics(
                windows_data,
                mpris_output=mpris_output,
                is_locked=is_locked,
                custom_game_ids=self.custom_game_ids,
            )

        def notify_posture(self):
            log("POSTURE REMINDER: Sent top-center 'Change position'")
            self.notifications_log.append((self.now_fn(), "movement-posture", "Change position"))
            if self.custom_notify:
                self.custom_notify("movement-posture", "Change position")
                return
            subprocess.run(
                [
                    "notify-send",
                    "--app-name=movement-posture",
                    "--hint=string:x-canonical-private-synchronous:movement",
                    f"--expire-time={POSTURE_NOTIFICATION_DURATION_MS}",
                    "Change position",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        def notify_break(self):
            log("BREAK REMINDER: Sent dead-center 'Get up and move'")
            self.notifications_log.append((self.now_fn(), "movement-break", "Get up and move"))
            if self.custom_notify:
                self.custom_notify("movement-break", "Get up and move")
                return
            subprocess.run(
                [
                    "notify-send",
                    "--app-name=movement-break",
                    "--hint=string:x-canonical-private-synchronous:movement",
                    f"--expire-time={BREAK_NOTIFICATION_DURATION_MS}",
                    "Get up and move",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )

        def handle_idle_event(self):
            """Called when swayidle signals user inactivity."""
            now = self.now_fn()
            self.accumulated_active_time = max(0.0, self.accumulated_active_time - self.idle_detection_timeout)
            self.idle_start_time = now - self.idle_detection_timeout
            self.pending_post_immersion_break = False
            log(f"IDLE DETECTED (inactive for {self.idle_detection_timeout}s)")

            if self.state == State.ACTIVE:
                self.set_state(State.IDLE_ORDINARY, "user inactive during active work")
            elif self.state == State.BREAK_DUE:
                self.set_state(State.IDLE_DURING_BREAK, "user inactive after break due")

        def handle_resume_event(self):
            """Called when swayidle signals user input resumed."""
            now = self.now_fn()
            idle_duration = max(0.0, now - self.idle_start_time)
            log(f"INPUT RESUMED (continuous idle was {idle_duration:.1f}s, qualifying={self.qualifying_break_idle}s)")

            if self.state == State.IDLE_ORDINARY:
                if idle_duration >= self.qualifying_break_idle:
                    self.accumulated_active_time = 0.0
                    self.posture_shown = False
                    self.set_state(State.ACTIVE, "natural break qualifying")
                else:
                    self.set_state(State.ACTIVE, "short pause ended")

            elif self.state == State.IDLE_DURING_BREAK:
                if idle_duration >= self.qualifying_break_idle:
                    self.accumulated_active_time = 0.0
                    self.posture_shown = False
                    self.set_state(State.ACTIVE, "break completed successfully")
                else:
                    self.set_state(State.BREAK_DUE, "attempted break too short (< qualifying)")

            elif self.state == State.BREAK_COMPLETED:
                self.accumulated_active_time = 0.0
                self.posture_shown = False
                self.set_state(State.ACTIVE, "fresh cycle started after break")

            self.last_tick_time = now

        def tick(self):
            """Periodic 1-second state machine tick."""
            now = self.now_fn()
            delta = now - self.last_tick_time
            self.last_tick_time = now

            # 1. Throttled Immersion Check & State Transition
            if now - self.last_immersion_poll_time >= self.immersion_poll_interval:
                self.last_immersion_poll_time = now
                current_immersive = self.check_system_immersion()

                if not self.is_immersive_active and current_immersive:
                    self.is_immersive_active = True
                    self.pending_post_immersion_break = False
                    log("IMMERSION: Started")
                elif self.is_immersive_active and not current_immersive:
                    self.is_immersive_active = False
                    self.immersion_exit_time = now
                    log(f"IMMERSION: Ended (grace period: {self.post_immersion_grace_period}s)")
                    if self.state == State.BREAK_DUE:
                        self.pending_post_immersion_break = True

            # 2. Check Post-Immersion Grace Period
            if self.pending_post_immersion_break and not self.is_immersive_active and self.state == State.BREAK_DUE:
                if now - self.immersion_exit_time >= self.post_immersion_grace_period:
                    self.pending_post_immersion_break = False
                    self.last_overdue_notify_time = now
                    self.notify_break()
                    log(f"BREAK REMINDER: Post-immersion grace period ({self.post_immersion_grace_period}s) elapsed, notifying now")

            # 3. State Machine Work Timer & Triggers
            if self.state == State.ACTIVE:
                self.accumulated_active_time += delta
                log(f"[{self.state.value}] active={self.accumulated_active_time:.1f}s / {self.break_interval}s")

                # Posture reminder check (25 min)
                if self.accumulated_active_time >= self.posture_interval and not self.posture_shown:
                    self.posture_shown = True
                    if not self.is_immersive_active:
                        self.notify_posture()
                    else:
                        log("POSTURE REMINDER: Skipped (transient posture threshold crossed during immersion)")

                # Break reminder check (50 min)
                if self.accumulated_active_time >= self.break_interval:
                    self.set_state(State.BREAK_DUE, "reached break threshold")
                    self.last_overdue_notify_time = now
                    if not self.is_immersive_active:
                        self.notify_break()
                    else:
                        log("BREAK REMINDER: Suppressed (became due during immersion; deferred to exit)")

            elif self.state == State.BREAK_DUE:
                self.accumulated_active_time += delta
                time_since_last_notify = now - self.last_overdue_notify_time
                log(f"[{self.state.value}] overdue_active (last_notify={time_since_last_notify:.1f}s ago)")

                if not self.is_immersive_active and not self.pending_post_immersion_break:
                    if time_since_last_notify >= self.overdue_reminder_interval:
                        self.last_overdue_notify_time = now
                        self.notify_break()

            elif self.state in (State.IDLE_ORDINARY, State.IDLE_DURING_BREAK):
                idle_duration = now - self.idle_start_time
                log(f"[{self.state.value}] continuous_idle={idle_duration:.1f}s / {self.qualifying_break_idle}s")
                if idle_duration >= self.qualifying_break_idle:
                    self.accumulated_active_time = 0.0
                    self.posture_shown = False
                    self.set_state(State.BREAK_COMPLETED, "idle reached qualifying break duration")

            elif self.state == State.BREAK_COMPLETED:
                log(f"[{self.state.value}] idle waiting for user return")


    class TestMovementReminder(unittest.TestCase):
        def setUp(self):
            self.current_time = 1000.0
            self.is_immersive = False
            self.engine = MovementReminder(
                posture_interval=25 * 60,
                break_interval=50 * 60,
                qualifying_break_idle=5 * 60,
                overdue_reminder_interval=5 * 60,
                idle_detection_timeout=90,
                post_immersion_grace_period=8,
                immersion_poll_interval=1,
                now_fn=lambda: self.current_time,
                is_immersive_fn=lambda: self.is_immersive,
            )

        def advance_time(self, seconds, tick_step=1.0):
            target = self.current_time + seconds
            while self.current_time < target:
                step = min(tick_step, target - self.current_time)
                self.current_time += step
                self.engine.tick()

        def test_1_posture_reminder_at_25_min(self):
            self.advance_time(24 * 60)
            self.assertEqual(len(self.engine.notifications_log), 0)
            self.assertEqual(self.engine.state, State.ACTIVE)

            self.advance_time(1 * 60)
            self.assertEqual(len(self.engine.notifications_log), 1)
            self.assertEqual(self.engine.notifications_log[0][1], "movement-posture")
            self.assertEqual(self.engine.notifications_log[0][2], "Change position")
            self.assertEqual(self.engine.state, State.ACTIVE)

        def test_2_break_reminder_at_50_min(self):
            self.advance_time(50 * 60)
            self.assertEqual(len(self.engine.notifications_log), 2)
            self.assertEqual(self.engine.notifications_log[1][1], "movement-break")
            self.assertEqual(self.engine.notifications_log[1][2], "Get up and move")
            self.assertEqual(self.engine.state, State.BREAK_DUE)

        def test_3_qualifying_break_5_min(self):
            self.advance_time(50 * 60)
            self.assertEqual(self.engine.state, State.BREAK_DUE)

            self.advance_time(90)
            self.engine.handle_idle_event()
            self.assertEqual(self.engine.state, State.IDLE_DURING_BREAK)

            self.advance_time(300)
            self.assertEqual(self.engine.state, State.BREAK_COMPLETED)
            self.assertEqual(self.engine.accumulated_active_time, 0.0)

            self.engine.handle_resume_event()
            self.assertEqual(self.engine.state, State.ACTIVE)
            self.assertEqual(self.engine.accumulated_active_time, 0.0)

        def test_4_short_incomplete_break_rejected(self):
            self.advance_time(50 * 60)
            self.assertEqual(self.engine.state, State.BREAK_DUE)

            self.advance_time(90)
            self.engine.handle_idle_event()
            self.assertEqual(self.engine.state, State.IDLE_DURING_BREAK)

            self.advance_time(60)
            self.engine.handle_resume_event()
            self.assertEqual(self.engine.state, State.BREAK_DUE)
            self.assertGreaterEqual(self.engine.accumulated_active_time, 48 * 60)

        def test_5_overdue_reminders_every_5_min(self):
            self.advance_time(50 * 60)
            self.assertEqual(len(self.engine.notifications_log), 2)

            self.advance_time(4 * 60)
            self.assertEqual(len(self.engine.notifications_log), 2)

            self.advance_time(1 * 60)
            self.assertEqual(len(self.engine.notifications_log), 3)
            self.assertEqual(self.engine.notifications_log[2][1], "movement-break")

            self.advance_time(5 * 60)
            self.assertEqual(len(self.engine.notifications_log), 4)

        def test_6_natural_break_during_work(self):
            self.advance_time(20 * 60)
            self.assertEqual(self.engine.accumulated_active_time, 20 * 60)

            self.advance_time(90)
            self.engine.handle_idle_event()
            self.advance_time(350)
            self.assertEqual(self.engine.state, State.BREAK_COMPLETED)

            self.engine.handle_resume_event()
            self.assertEqual(self.engine.state, State.ACTIVE)
            self.assertEqual(self.engine.accumulated_active_time, 0.0)

        def test_7_short_pause_resumes_without_reset(self):
            self.advance_time(20 * 60)

            self.advance_time(90)
            self.engine.handle_idle_event()
            self.advance_time(30)
            self.engine.handle_resume_event()

            self.assertEqual(self.engine.state, State.ACTIVE)
            self.assertAlmostEqual(self.engine.accumulated_active_time, 20 * 60, delta=2)

        def test_8_post_immersion_grace_period_break_prompt(self):
            """When immersion ends while break is overdue, wait for grace period (8s) then notify."""
            self.is_immersive = True
            self.advance_time(50 * 60)
            self.assertEqual(self.engine.state, State.BREAK_DUE)
            self.assertEqual(len(self.engine.notifications_log), 0)

            # Continue movie for 20 minutes
            self.advance_time(20 * 60)
            self.assertEqual(len(self.engine.notifications_log), 0)

            # Exit immersion -> grace period starts
            self.is_immersive = False
            self.advance_time(1)
            # Not immediately at 1s
            self.assertEqual(len(self.engine.notifications_log), 0)
            self.assertTrue(self.engine.pending_post_immersion_break)

            # After 8s grace period -> notification fires!
            self.advance_time(8)
            self.assertEqual(len(self.engine.notifications_log), 1)
            self.assertEqual(self.engine.notifications_log[0][1], "movement-break")
            self.assertFalse(self.engine.pending_post_immersion_break)

        def test_9_immersion_posture_transient_discard(self):
            """Posture reminder crossed during immersion is discarded for that cycle."""
            self.is_immersive = True
            self.advance_time(30 * 60)
            self.assertTrue(self.engine.posture_shown)
            self.assertEqual(len(self.engine.notifications_log), 0)

            self.is_immersive = False
            self.advance_time(10)
            self.assertEqual(len(self.engine.notifications_log), 0)

            self.advance_time(20 * 60)
            self.assertEqual(len(self.engine.notifications_log), 1)
            self.assertEqual(self.engine.notifications_log[0][1], "movement-break")

        def test_10_correlated_player_mpris_detection(self):
            """Tests player-specific MPRIS correlation with focused browser."""
            w_librewolf = [{"app_id": "librewolf", "is_focused": True, "is_fullscreen": True}]

            # Scenario A: Background Spotify is Playing, LibreWolf is Paused/Silent -> NOT IMMERSIVE
            mpris_spotify = "spotify\tPlaying\nlibrewolf.instance-1\tPaused"
            self.assertFalse(evaluate_immersive_heuristics(w_librewolf, mpris_output=mpris_spotify))

            # Scenario B: Background Spotify is Paused, LibreWolf video is Playing -> IMMERSIVE
            mpris_librewolf = "spotify\tPaused\nlibrewolf.instance-1\tPlaying"
            self.assertTrue(evaluate_immersive_heuristics(w_librewolf, mpris_output=mpris_librewolf))

            # Scenario C: Both Playing -> IMMERSIVE
            mpris_both = "spotify\tPlaying\nlibrewolf.instance-1\tPlaying"
            self.assertTrue(evaluate_immersive_heuristics(w_librewolf, mpris_output=mpris_both))

            # Scenario D: Terminal focused while LibreWolf is playing video in background -> NOT IMMERSIVE
            w_terminal = [
                {"app_id": "librewolf", "is_focused": False, "is_fullscreen": True},
                {"app_id": "foot", "is_focused": True, "is_fullscreen": False}
            ]
            self.assertFalse(evaluate_immersive_heuristics(w_terminal, mpris_output=mpris_librewolf))

        def test_11_game_detection_patterns(self):
            """Tests game detection across steam, gamescope, lutris, and custom env list."""
            # Steam game
            self.assertTrue(evaluate_immersive_heuristics([{"app_id": "steam_app_570", "is_focused": True, "is_fullscreen": True}]))
            # Gamescope session
            self.assertTrue(evaluate_immersive_heuristics([{"app_id": "gamescope", "is_focused": True, "is_fullscreen": True}]))
            # Lutris game
            self.assertTrue(evaluate_immersive_heuristics([{"app_id": "lutris", "is_focused": True, "is_fullscreen": True}]))
            # Custom game via env
            self.assertTrue(evaluate_immersive_heuristics(
                [{"app_id": "factorio", "is_focused": True, "is_fullscreen": True}],
                custom_game_ids=["factorio"]
            ))

        def test_12_paused_fullscreen_media_not_immersive(self):
            """Tests that paused MPV or paused browser video does NOT suppress reminders."""
            w_mpv = [{"app_id": "mpv", "is_focused": True, "is_fullscreen": True}]

            # MPV Playing -> Immersive
            self.assertTrue(evaluate_immersive_heuristics(w_mpv, mpris_output="mpv\tPlaying"))

            # MPV Paused -> NOT Immersive
            self.assertFalse(evaluate_immersive_heuristics(w_mpv, mpris_output="mpv\tPaused"))


    async def read_swayidle(reminder: MovementReminder):
        cmd = [
            "swayidle",
            "-w",
            "-C",
            "/dev/null",
            "timeout",
            str(reminder.idle_detection_timeout),
            "echo IDLE",
            "resume",
            "echo RESUME",
        ]
        while True:
            try:
                proc = await asyncio.create_subprocess_exec(
                    *cmd,
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                reminder.swayidle_proc = proc
                while True:
                    line = await proc.stdout.readline()
                    if not line:
                        break
                    decoded = line.decode().strip()
                    if decoded == "IDLE":
                        reminder.handle_idle_event()
                    elif decoded == "RESUME":
                        reminder.handle_resume_event()
                await proc.wait()
            except Exception as e:
                log(f"swayidle loop warning: {e}")
                await asyncio.sleep(2)


    async def main():
        if is_self_test:
            suite = unittest.TestLoader().loadTestsFromTestCase(TestMovementReminder)
            runner = unittest.TextTestRunner(verbosity=2)
            result = runner.run(suite)
            sys.exit(0 if result.wasSuccessful() else 1)

        reminder = MovementReminder()
        asyncio.create_task(read_swayidle(reminder))

        while True:
            reminder.tick()
            await asyncio.sleep(1)


    if __name__ == "__main__":
        try:
            asyncio.run(main())
        except KeyboardInterrupt:
            pass
    PYEOF
  '';
}
