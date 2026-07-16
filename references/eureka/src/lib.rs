// SPDX-License-Identifier: GPL-3.0-or-later

use std::cell::RefCell;
use std::collections::HashMap;
use std::io::ErrorKind;
use std::io::Write;
use std::os::fd::AsFd;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex};

use anyhow::{Context, anyhow, bail};
use emacs::{Env, FromLisp, IntoLisp, Result, Value, Vector, defun, use_symbols};
use nix::poll::PollTimeout;
use nix::sys::eventfd::{EfdFlags, EventFd};
use wayland_client::{
    Connection, Dispatch, WEnum,
    protocol::{wl_output, wl_registry},
};
use xkbcommon::xkb;

use crate::river::{
    river_input_device_v1::RiverInputDeviceV1,
    river_input_manager_v1::RiverInputManagerV1,
    river_layer_shell_output_v1::RiverLayerShellOutputV1,
    river_layer_shell_seat_v1::RiverLayerShellSeatV1,
    river_layer_shell_v1::RiverLayerShellV1,
    river_libinput_config_v1::RiverLibinputConfigV1,
    river_libinput_device_v1::RiverLibinputDeviceV1,
    river_libinput_result_v1::RiverLibinputResultV1,
    river_output_v1::RiverOutputV1,
    river_seat_v1::Modifiers,
    river_window_manager_v1::RiverWindowManagerV1,
    river_window_v1::{Edges, RiverWindowV1},
    river_xkb_binding_v1::RiverXkbBindingV1,
    river_xkb_bindings_v1::RiverXkbBindingsV1,
};
use model::{ClientLifecycle, FocusTarget, Generation};

mod model;
mod river;

emacs::plugin_is_GPL_compatible!();

use_symbols!(
    cons
    list
    key_event
    new_window
    window_closed
    minimize_requested
    focused
    title_change
    app_id_change
    frame_request
    discard_frame
    toggle_fullscreen
    message
    fatal_error => "fatal-error"
);

macro_rules! dispatch_log_only {
    ($proxy_ty:ty) => {
        impl Dispatch<$proxy_ty, ()> for Eureka {
            fn event(
                _: &mut Self,
                _: &$proxy_ty,
                _event: <$proxy_ty as wayland_client::Proxy>::Event,
                _: &(),
                _: &Connection,
                _: &wayland_client::QueueHandle<Self>,
            ) {
            }
        }
    };
}

#[emacs::module(name = "libeureka", defun_prefix = "eureka")]
fn init(_: &Env) -> Result<()> {
    Ok(())
}

#[derive(Clone, Debug)]
enum KeyEvent {
    KeyCode(u32),
    Symbol(String),
}

impl<'e> FromLisp<'e> for KeyEvent {
    fn from_lisp(value: Value<'e>) -> Result<Self> {
        if let Ok(key_code) = u32::from_lisp(value) {
            return Ok(KeyEvent::KeyCode(key_code));
        }

        if let Ok(symbol_name) = String::from_lisp(value) {
            return Ok(KeyEvent::Symbol(symbol_name));
        }

        bail!("could not decode key event, eureka bug?");
    }
}

impl<'e> IntoLisp<'e> for KeyEvent {
    fn into_lisp(self, env: &'e Env) -> Result<Value<'e>> {
        match self {
            KeyEvent::KeyCode(c) => c.into_lisp(env),
            KeyEvent::Symbol(name) => env.intern(&name),
        }
    }
}

#[derive(Debug)]
enum Command {
    /// Always forward the binding to Emacs
    Forward(KeyEvent),

    /// Toggle fullscreen for the selected window
    ToggleFullscreen,
}

#[derive(Clone, Copy, Debug)]
struct RiverInputConfig {
    repeat_rate: i32,
    repeat_delay: i32,
    touchpad_accel_speed: f64,
    mouse_accel_speed: f64,
    touchpad_tap: bool,
    touchpad_natural_scroll: bool,
    touchpad_disable_while_typing: bool,
    touchpad_disable_while_trackpointing: bool,
    touchpad_drag_lock: bool,
    touchpad_two_finger_scroll: bool,
    touchpad_accel_profile: AccelProfile,
    mouse_accel_profile: AccelProfile,
}

#[derive(Clone, Copy, Debug)]
enum AccelProfile {
    Adaptive,
    Flat,
}

impl AccelProfile {
    fn parse(value: &str) -> Result<Self> {
        match value {
            "adaptive" => Ok(Self::Adaptive),
            "flat" => Ok(Self::Flat),
            _ => bail!("acceleration profile must be `adaptive' or `flat'"),
        }
    }

    fn protocol_value(self) -> river::river_libinput_device_v1::AccelProfile {
        match self {
            Self::Adaptive => river::river_libinput_device_v1::AccelProfile::Adaptive,
            Self::Flat => river::river_libinput_device_v1::AccelProfile::Flat,
        }
    }
}

impl Default for RiverInputConfig {
    fn default() -> Self {
        Self {
            repeat_rate: 60,
            repeat_delay: 200,
            touchpad_accel_speed: 0.3,
            mouse_accel_speed: 0.0,
            touchpad_tap: true,
            touchpad_natural_scroll: true,
            touchpad_disable_while_typing: true,
            touchpad_disable_while_trackpointing: true,
            touchpad_drag_lock: true,
            touchpad_two_finger_scroll: true,
            touchpad_accel_profile: AccelProfile::Adaptive,
            mouse_accel_profile: AccelProfile::Flat,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum InputDeviceKind {
    Unknown,
    Keyboard,
    Pointer,
    Touch,
    Tablet,
}

#[derive(Debug)]
struct InputDevice {
    kind: InputDeviceKind,
}

#[derive(Debug, Default)]
struct LibinputDevice {
    input_device: Option<RiverInputDeviceV1>,
    saw_tap_support: bool,
    is_touchpad: bool,
    configured_as_touchpad: bool,
    configured_as_mouse: bool,
}

fn command_from_lisp<'e>(command: Value<'e>, event: KeyEvent) -> Result<Command> {
    if command.is_not_nil() {
        if toggle_fullscreen.eq(&command) {
            return Ok(Command::ToggleFullscreen);
        }

        return Err(anyhow!("unknown builtin command"));
    }

    Ok(Command::Forward(event))
}

#[derive(Debug)]
enum FromEmacs {
    RegisterPrefix(XKBPrefix, Command),
    SetInputConfig(RiverInputConfig),
    CloseWindow(u64),
    BufferCreated(u64),
    SyncState {
        generation: u64,
        parameters: Option<HashMap<u64, WindowParameters>>,
        focus: FocusTarget,
    },
    ExitFullscreen,
    Stop,
    ExitSession,
}

#[derive(Debug)]
enum ToEmacs {
    KeyEvent(KeyEvent),
    NewWindow(u64),
    WindowClosed(u64),
    Focused(u64),
    TitleChange(u64, String),
    AppIDChange(u64, String),
    MinimizeRequested(u64),
    RequestFrame,
    DiscardFrame(String),
    Message(String),
    FatalError(String),
}

impl<'e> IntoLisp<'e> for ToEmacs {
    fn into_lisp(self, env: &'e Env) -> Result<Value<'e>> {
        match self {
            ToEmacs::KeyEvent(event) => env.cons(key_event, event),
            ToEmacs::NewWindow(id) => env.cons(new_window, id),
            ToEmacs::WindowClosed(id) => env.cons(window_closed, id),
            ToEmacs::MinimizeRequested(id) => env.cons(minimize_requested, id),
            ToEmacs::Focused(id) => env.cons(focused, id),
            ToEmacs::AppIDChange(id, app_id) => env.call(list, (app_id_change, id, app_id)),
            ToEmacs::TitleChange(id, title) => env.call(list, (title_change, id, title)),
            ToEmacs::RequestFrame => frame_request.into_lisp(env),
            ToEmacs::DiscardFrame(frame_name) => env.call(cons, (discard_frame, frame_name)),
            ToEmacs::Message(text) => env.cons(message, text),
            ToEmacs::FatalError(text) => env.cons(fatal_error, text),
        }
    }
}

struct Handle {
    fd: Arc<EventFd>,
    tx: Sender<FromEmacs>,
    rx: Receiver<ToEmacs>,
    from_emacs_wake_pending: Arc<AtomicBool>,
    to_emacs_wake_pending: Arc<AtomicBool>,
}

impl Handle {
    fn send(&self, msg: FromEmacs) -> Result<()> {
        self.tx.send(msg)?;
        if !self.from_emacs_wake_pending.swap(true, Ordering::AcqRel)
            && let Err(err) = self.fd.write(1)
        {
            self.from_emacs_wake_pending.store(false, Ordering::Release);
            return Err(err.into());
        }
        Ok(())
    }
}

impl Drop for Handle {
    fn drop(&mut self) {
        // Emacs can garbage-collect the user pointer without calling stop-wm.
        // Wake the worker so it does not remain blocked in poll forever.
        let _ = self.send(FromEmacs::Stop);
    }
}

/// Request closing of the Wayland surface WINDOW through HANDLE. Note that
/// window refers to the Wayland side, not to an Emacs window.
///
/// This function should not need to be called manually.
#[defun]
fn close_window<'e>(env: &'e Env, handle: &Handle, window_id: u64) -> Result<Value<'e>> {
    handle.send(FromEmacs::CloseWindow(window_id))?;
    ().into_lisp(env)
}

/// Exit fullscreen on the output containing the selected Emacs frame.
#[defun]
fn exit_fullscreen<'e>(env: &'e Env, handle: &Handle) -> Result<Value<'e>> {
    handle.send(FromEmacs::ExitFullscreen)?;
    ().into_lisp(env)
}

/// Ask river to end the current Wayland session.
#[defun]
fn exit_session<'e>(env: &'e Env, handle: &Handle) -> Result<Value<'e>> {
    handle.send(FromEmacs::ExitSession)?;
    ().into_lisp(env)
}

/// Stop Eureka's native event loop without terminating the River session.
#[defun]
fn stop_wm<'e>(env: &'e Env, handle: &Handle) -> Result<Value<'e>> {
    handle.send(FromEmacs::Stop)?;
    ().into_lisp(env)
}

/// Configure River input devices managed by Eureka.
#[defun]
#[allow(clippy::too_many_arguments)] // Flat Emacs module ABI; Lisp owns this policy.
fn configure_input<'e>(
    env: &'e Env,
    handle: &Handle,
    repeat_rate: i32,
    repeat_delay: i32,
    touchpad_accel_speed: f64,
    mouse_accel_speed: f64,
    touchpad_tap: Value<'e>,
    touchpad_natural_scroll: Value<'e>,
    touchpad_disable_while_typing: Value<'e>,
    touchpad_disable_while_trackpointing: Value<'e>,
    touchpad_drag_lock: Value<'e>,
    touchpad_two_finger_scroll: Value<'e>,
    touchpad_accel_profile: String,
    mouse_accel_profile: String,
) -> Result<Value<'e>> {
    if repeat_rate < 0 || repeat_delay < 0 {
        return Err(anyhow!(
            "keyboard repeat rate and delay must be non-negative"
        ));
    }
    if !touchpad_accel_speed.is_finite()
        || !mouse_accel_speed.is_finite()
        || !(-1.0..=1.0).contains(&touchpad_accel_speed)
        || !(-1.0..=1.0).contains(&mouse_accel_speed)
    {
        return Err(anyhow!(
            "pointer acceleration speed must be between -1.0 and 1.0"
        ));
    }

    handle.send(FromEmacs::SetInputConfig(RiverInputConfig {
        repeat_rate,
        repeat_delay,
        touchpad_accel_speed,
        mouse_accel_speed,
        touchpad_tap: touchpad_tap.is_not_nil(),
        touchpad_natural_scroll: touchpad_natural_scroll.is_not_nil(),
        touchpad_disable_while_typing: touchpad_disable_while_typing.is_not_nil(),
        touchpad_disable_while_trackpointing: touchpad_disable_while_trackpointing.is_not_nil(),
        touchpad_drag_lock: touchpad_drag_lock.is_not_nil(),
        touchpad_two_finger_scroll: touchpad_two_finger_scroll.is_not_nil(),
        touchpad_accel_profile: AccelProfile::parse(&touchpad_accel_profile)?,
        mouse_accel_profile: AccelProfile::parse(&mouse_accel_profile)?,
    }))?;
    ().into_lisp(env)
}

type EmacsChannel = Arc<Mutex<Box<dyn std::io::Write + Send>>>;

/// Start the eureka window manager process. This should not be called manually,
/// instead see `eureka-enable` for the user-facing function.
#[defun(user_ptr)]
fn start_wm(env: &Env, pipe: Value<'_>, frame_prefix: String) -> Result<Handle> {
    let channel_file: EmacsChannel = Arc::new(Mutex::new(Box::new(env.open_channel(pipe)?)));
    let error_channel = channel_file.clone();

    let (tx, rx) = channel::<FromEmacs>();
    let (tx_e, rx_e) = channel::<ToEmacs>();
    let tx_error = tx_e.clone();

    let emacs_fd = Arc::new(EventFd::from_value_and_flags(0, EfdFlags::EFD_NONBLOCK)?);
    let emacs_fd_wmside = emacs_fd.clone();
    let from_emacs_wake_pending = Arc::new(AtomicBool::new(false));
    let from_emacs_wake_pending_wmside = from_emacs_wake_pending.clone();
    let to_emacs_wake_pending = Arc::new(AtomicBool::new(false));
    let to_emacs_wake_pending_wmside = to_emacs_wake_pending.clone();
    let to_emacs_wake_pending_error = to_emacs_wake_pending.clone();

    std::thread::spawn(move || {
        let result = wm_loop(
            rx,
            tx_e,
            channel_file,
            emacs_fd_wmside,
            from_emacs_wake_pending_wmside,
            to_emacs_wake_pending_wmside,
            frame_prefix,
        );
        if let Err(e) = result {
            log::error!("eureka window manager thread crashed: {:?}", e);
            let _ = tx_error.send(ToEmacs::FatalError(format!("{e:#}")));
            if !to_emacs_wake_pending_error.swap(true, Ordering::AcqRel)
                && let Ok(mut channel) = error_channel.lock()
            {
                let _ = channel.write_all(&[1]);
            }
        }
    });

    env.message("launched eureka window manager! have fun ...")?;
    Ok(Handle {
        fd: emacs_fd,
        tx,
        rx: rx_e,
        from_emacs_wake_pending,
        to_emacs_wake_pending,
    })
}

#[derive(Clone, Debug, PartialEq)]
struct WindowParameters {
    window_id: u64,
    frame_name: String,
    x: i32,
    y: i32,
    h: i32,
    w: i32,
}

/// Construct an opaque window parameters object describing the display position
/// and dimensions for a given Wayland surface. This is an internal eureka
/// function.
#[defun(user_ptr)]
fn make_window_parameters(
    _env: &Env,
    window_id: u64,
    frame_name: String,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
) -> Result<WindowParameters> {
    let params = WindowParameters {
        window_id,
        frame_name,
        x,
        y,
        w,
        h,
    };

    Ok(params)
}

fn decode_window_parameters<'e>(per_frame: Vector<'e>) -> Result<HashMap<u64, WindowParameters>> {
    let mut new_params = HashMap::new();
    for elem in per_frame.into_iter() {
        let params: Vector<'e> = elem.into_rust()?;
        for p in params.into_iter() {
            let wp: &RefCell<WindowParameters> = p.into_rust()?;
            let params = wp.borrow().clone();
            new_params.insert(params.window_id, params);
        }
    }
    Ok(new_params)
}

/// Publish Emacs's current layout and focus as one ordered state update.
/// PER_FRAME may be nil when geometry has not changed since the previous
/// generation. WINDOW_ID nil means keyboard focus should return to Emacs.
#[defun]
fn sync_state<'e>(
    env: &'e Env,
    handle: &Handle,
    generation: u64,
    per_frame: Value<'e>,
    window_id: Value<'e>,
) -> Result<Value<'e>> {
    let parameters = if per_frame.is_not_nil() {
        Some(decode_window_parameters(per_frame.into_rust()?)?)
    } else {
        None
    };
    let focus = if window_id.is_not_nil() {
        FocusTarget::Window(window_id.into_rust()?)
    } else {
        FocusTarget::Frame
    };

    handle.send(FromEmacs::SyncState {
        generation,
        parameters,
        focus,
    })?;

    ().into_lisp(env)
}

/// Confirm that the Emacs-side buffer for a given window was created.
///
/// This is an internal function.
#[defun]
fn notify_buffer_created<'e>(env: &'e Env, handle: &Handle, window_id: u64) -> Result<Value<'e>> {
    handle.send(FromEmacs::BufferCreated(window_id))?;
    ().into_lisp(env)
}

/// Register the given key prefix for global use in eureka. This function is
/// internal and difficult to call correctly, please see
/// `eureka-push-intercept-prefix` for the user-facing version.
#[defun]
fn register_xkb_prefix<'e>(
    env: &'e Env,
    handle: &Handle,
    event: KeyEvent,
    key: Value<'e>,
    modifiers_bits: u32,
    command: Value<'e>,
) -> Result<Value<'e>> {
    // Emacs hands us either an int (Unicode codepoint for the key), or a string
    // with a "key name". The later is stuff like "XF86AudioRaiseVolume",
    // "Return", etc. which we map back to a keysym with XKB here.
    let keysym = if let Ok(codepoint) = key.into_rust::<i64>() {
        xkb::utf32_to_keysym(codepoint as u32)
    } else {
        let name: String = key.into_rust()?;
        xkb::keysym_from_name(&name, xkb::KEYSYM_CASE_INSENSITIVE)
    };

    if keysym == xkb::keysyms::KEY_NoSymbol.into() {
        return Err(anyhow!("could not resolve XKB keysym for key"));
    }

    let modifiers = Modifiers::from_bits(modifiers_bits).context("unknown modifier bits")?;

    let prefix = XKBPrefix {
        keysym: u32::from(keysym),
        modifiers,
    };

    let command = command_from_lisp(command, event)?;
    handle.send(FromEmacs::RegisterPrefix(prefix, command))?;

    ().into_lisp(env)
}

/// Receive the next eureka->emacs command that should be handled. This is an
/// internal function.
#[defun]
fn get_next_command<'e>(env: &'e Env, handle: &Handle) -> Result<Value<'e>> {
    match handle.rx.try_recv() {
        Ok(cmd) => {
            return cmd.into_lisp(env);
        }
        Err(std::sync::mpsc::TryRecvError::Empty) => {
            handle.to_emacs_wake_pending.store(false, Ordering::Release);
            if let Ok(cmd) = handle.rx.try_recv() {
                handle.to_emacs_wake_pending.store(true, Ordering::Release);
                return cmd.into_lisp(env);
            }
        }
        Err(std::sync::mpsc::TryRecvError::Disconnected) => {}
    }

    ().into_lisp(env)
}

fn wm_loop(
    rx: Receiver<FromEmacs>,
    tx: Sender<ToEmacs>,
    to_emacs: EmacsChannel,
    emacs_fd: Arc<EventFd>,
    from_emacs_wake_pending: Arc<AtomicBool>,
    to_emacs_wake_pending: Arc<AtomicBool>,
    frame_prefix: String,
) -> Result<()> {
    let _ = env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("trace"))
        .target(env_logger::Target::Stderr)
        .try_init();
    log::set_max_level(if std::env::var_os("EUREKA_DEBUG").is_some() {
        log::LevelFilter::Debug
    } else {
        log::LevelFilter::Warn
    });

    let pid = std::process::id() as i32;

    log::info!("starting eureka window manager thread (PID {}) ...", pid);
    let conn = Connection::connect_to_env().context("setting up Wayland connection")?;
    let display = conn.display();
    let mut event_queue = conn.new_event_queue();
    let qh = event_queue.handle();
    let mut wm = Eureka {
        pid,
        frame_prefix,
        rx,
        tx,
        to_emacs,
        from_emacs: emacs_fd,
        seat: None,
        focus: Focus {
            dirty: false,
            state: FocusState::Lost,
        },
        frames: HashMap::new(),
        outputs: HashMap::new(),
        windows: HashMap::new(),
        windows_by_id: HashMap::new(),
        river_wm: None,
        xkb_bindings: None,
        layer_shell: None,
        input_config: RiverInputConfig::default(),
        input_manager: None,
        libinput_config: None,
        input_devices: HashMap::new(),
        libinput_devices: HashMap::new(),
        prefixes: Default::default(),
        pending_frames: 0,
        next_window_id: 1,
        state_generation: Generation::default(),
        from_emacs_wake_pending,
        to_emacs_wake_pending,
        running: true,
        stopping: false,
    };
    let _registry = display.get_registry(&qh, ());

    loop {
        if !wm.running {
            return Ok(());
        }

        let flush_blocked = match event_queue.flush() {
            Ok(()) => false,
            Err(wayland_client::backend::WaylandError::Io(err))
                if err.kind() == ErrorKind::WouldBlock =>
            {
                true
            }
            Err(err) => return Err(err.into()),
        };
        let guard = match event_queue.prepare_read() {
            Some(g) => g,
            None => {
                event_queue.dispatch_pending(&mut wm)?;
                continue;
            }
        };

        let river_fd = guard.connection_fd();

        let (emacs_ready, river_ready) = {
            let mut polls = [
                nix::poll::PollFd::new(wm.from_emacs.as_fd(), nix::poll::PollFlags::POLLIN),
                nix::poll::PollFd::new(
                    river_fd,
                    nix::poll::PollFlags::POLLIN
                        | if flush_blocked {
                            nix::poll::PollFlags::POLLOUT
                        } else {
                            nix::poll::PollFlags::empty()
                        },
                ),
            ];

            let count = loop {
                match nix::poll::poll(&mut polls, PollTimeout::NONE) {
                    Ok(c) => break c,
                    Err(nix::errno::Errno::EINTR) => {
                        log::debug!("poll interrupted, continuing");
                        continue;
                    }
                    Err(e) => return Err(e).context("while polling emacs/river"),
                }
            };

            if count == 0 {
                continue;
            }

            let emacs_events = polls[0]
                .revents()
                .unwrap_or_else(nix::poll::PollFlags::empty);
            let river_events = polls[1]
                .revents()
                .unwrap_or_else(nix::poll::PollFlags::empty);
            let poll_errors = nix::poll::PollFlags::POLLERR
                | nix::poll::PollFlags::POLLHUP
                | nix::poll::PollFlags::POLLNVAL;

            if emacs_events.intersects(poll_errors) {
                bail!("Emacs event channel disconnected: {emacs_events:?}");
            }
            if river_events.intersects(poll_errors) {
                bail!("River connection disconnected: {river_events:?}");
            }

            (
                emacs_events.contains(nix::poll::PollFlags::POLLIN),
                river_events.contains(nix::poll::PollFlags::POLLIN),
            )
        };

        if emacs_ready {
            wm.handle_emacs(&qh);
            if !wm.running {
                return Ok(());
            }
        }

        if river_ready {
            guard.read()?;
            event_queue.dispatch_pending(&mut wm)?;
        }
    }
}

enum FullscreenState {
    None,
    Requested {
        new: RiverWindowV1,
        previous: Option<RiverWindowV1>,
    },
    Fullscreen(RiverWindowV1),
    Exiting(RiverWindowV1),
}

struct Output {
    proxy: RiverOutputV1,
    ls_output: Option<RiverLayerShellOutputV1>,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    fullscreen: FullscreenState,
}

impl Drop for Output {
    fn drop(&mut self) {
        self.proxy.destroy();
        if let Some(output) = self.ls_output.take() {
            output.destroy();
        }
    }
}

struct Frame {
    name: Option<String>,
    displayed_on: Option<RiverOutputV1>,
    node: river::river_node_v1::RiverNodeV1,
    proxy: RiverWindowV1,
    visible: bool,
    last_position: Option<(i32, i32)>,
    last_proposed_dimensions: Option<(i32, i32)>,
}

impl Drop for Frame {
    fn drop(&mut self) {
        // do NOT destroy displayed_on, output drop handles this
        self.proxy.destroy();
        self.node.destroy();
    }
}

#[derive(Debug)]
struct Window {
    id: u64,
    proxy: RiverWindowV1,
    node: river::river_node_v1::RiverNodeV1,
    lifecycle: ClientLifecycle,
    params: Option<WindowParameters>,
    actual_width_height: Option<(i32, i32)>,
    visible: bool,
    tiled: bool,
    last_position: Option<(i32, i32)>,
    last_clip: Option<(i32, i32)>,
    last_proposed_dimensions: Option<(i32, i32)>,
}

impl Drop for Window {
    fn drop(&mut self) {
        self.proxy.destroy();
        self.node.destroy();
    }
}

struct Seat {
    proxy: river::river_seat_v1::RiverSeatV1,
    #[allow(dead_code)] // TODO(tazjin): do I *need* to store this?
    ls_seat: Option<RiverLayerShellSeatV1>,
}

impl Drop for Seat {
    fn drop(&mut self) {
        self.proxy.destroy();
        if let Some(seat) = self.ls_seat.take() {
            seat.destroy();
        }
    }
}

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
struct XKBPrefix {
    keysym: u32,
    modifiers: Modifiers,
}

#[derive(Debug)]
enum BindingState {
    Requested,
    Registered(RiverXkbBindingV1),
    Enabled(RiverXkbBindingV1),
}

impl Drop for BindingState {
    fn drop(&mut self) {
        if let BindingState::Enabled(binding) = self {
            binding.destroy();
        }
    }
}

#[derive(Debug)]
struct Binding {
    #[allow(dead_code)]
    command: Command,
    state: BindingState,
}

enum FocusState {
    Lost,
    Frame(RiverWindowV1),
    Window {
        window: RiverWindowV1,
        on_frame: RiverWindowV1,
    },
}

struct Focus {
    dirty: bool,
    state: FocusState,
}

impl Focus {
    fn mark_dirty(&mut self) {
        self.dirty = true;
    }

    fn is_dirty(&mut self) -> bool {
        std::mem::replace(&mut self.dirty, false)
    }

    fn lost_focus(&self) -> bool {
        matches!(self.state, FocusState::Lost)
    }

    fn current_focus_and_frame(&self) -> Option<(&RiverWindowV1, &RiverWindowV1)> {
        match &self.state {
            FocusState::Lost => None,
            FocusState::Frame(frame) => Some((frame, frame)),
            FocusState::Window { window, on_frame } => Some((window, on_frame)),
        }
    }

    /// invalidate a window, meaning it can not be focused anymore (e.g. was closed)
    fn invalidate(&mut self, target: &RiverWindowV1) {
        match &self.state {
            FocusState::Frame(w) | FocusState::Window { on_frame: w, .. } if w.eq(target) => {
                self.state = FocusState::Lost;
            }
            FocusState::Window { window, on_frame } if window.eq(target) => {
                self.state = FocusState::Frame(on_frame.clone());
            }
            _ => {}
        }
    }

    fn focus_window(&mut self, window: RiverWindowV1, on_frame: RiverWindowV1) {
        let changed = !matches!(
            &self.state,
            FocusState::Window { window: current, on_frame: frame }
                if current == &window && frame == &on_frame
        );
        self.state = FocusState::Window { window, on_frame };
        self.dirty |= changed;
    }

    fn focus_frame(&mut self, frame: RiverWindowV1) {
        let changed = !matches!(&self.state, FocusState::Frame(current) if current == &frame);
        self.state = FocusState::Frame(frame);
        self.dirty |= changed;
    }

    fn switch_to_frame(&mut self) {
        if let FocusState::Window { on_frame, .. } = &self.state {
            self.focus_frame(on_frame.clone());
        }
    }
}

struct Eureka {
    pid: i32,
    frame_prefix: String,

    // Emacs-related state
    rx: Receiver<FromEmacs>,
    tx: Sender<ToEmacs>,
    to_emacs: EmacsChannel,
    from_emacs: Arc<EventFd>,
    pending_frames: usize,
    next_window_id: u64,
    state_generation: Generation,
    from_emacs_wake_pending: Arc<AtomicBool>,
    to_emacs_wake_pending: Arc<AtomicBool>,
    running: bool,
    stopping: bool,

    // river-related state
    river_wm: Option<RiverWindowManagerV1>,
    xkb_bindings: Option<RiverXkbBindingsV1>,
    layer_shell: Option<RiverLayerShellV1>,
    input_config: RiverInputConfig,
    input_manager: Option<RiverInputManagerV1>,
    libinput_config: Option<RiverLibinputConfigV1>,

    seat: Option<Seat>,
    focus: Focus,

    frames: HashMap<RiverWindowV1, Frame>,
    outputs: HashMap<RiverOutputV1, Output>,
    windows: HashMap<RiverWindowV1, Window>,
    windows_by_id: HashMap<u64, RiverWindowV1>,
    input_devices: HashMap<RiverInputDeviceV1, InputDevice>,
    libinput_devices: HashMap<RiverLibinputDeviceV1, LibinputDevice>,
    prefixes: HashMap<XKBPrefix, Binding>,
}

impl Drop for Eureka {
    fn drop(&mut self) {
        // Destroy everything else before tearing down the WM objects.
        self.prefixes.clear();
        self.windows.clear();
        self.windows_by_id.clear();
        self.frames.clear();
        self.outputs.clear();
        self.seat.take();

        if let Some(bindings) = self.xkb_bindings.take() {
            bindings.destroy();
        }

        if let Some(layer_shell) = self.layer_shell.take() {
            layer_shell.destroy();
        }

        self.libinput_devices.clear();
        for (device, _) in self.input_devices.drain() {
            device.destroy();
        }

        if let Some(libinput_config) = self.libinput_config.take() {
            libinput_config.stop();
        }

        if let Some(input_manager) = self.input_manager.take() {
            input_manager.stop();
        }

        if let Some(wm) = self.river_wm.take() {
            wm.destroy();
        }
    }
}

impl Eureka {
    fn send(&mut self, cmd: ToEmacs) {
        if let Err(err) = self.tx.send(cmd) {
            log::error!("could not send message to Emacs: {}", err);
            return;
        }
        if !self.to_emacs_wake_pending.swap(true, Ordering::AcqRel) {
            let result = self
                .to_emacs
                .lock()
                .map_err(|_| std::io::Error::other("Emacs channel lock poisoned"))
                .and_then(|mut channel| channel.write_all(&[1]));
            if let Err(err) = result {
                log::error!("could not notify Emacs: {}", err);
                self.to_emacs_wake_pending.store(false, Ordering::Release);
            }
        }
    }

    fn frame_by_name(&self, name: &str) -> Option<&Frame> {
        self.frames
            .iter()
            .find(|(_, f)| f.name.as_deref() == Some(name))
            .map(|x| x.1)
    }

    fn displaying_frame(&self, window: &RiverWindowV1) -> Option<&Frame> {
        self.windows
            .get(window)
            .and_then(|w| w.params.as_ref())
            .and_then(|p| self.frame_by_name(&p.frame_name))
    }

    fn window_proxy(&self, id: u64) -> Option<RiverWindowV1> {
        self.windows_by_id.get(&id).cloned()
    }

    fn window_id(&self, proxy: &RiverWindowV1) -> Option<u64> {
        self.windows.get(proxy).map(|window| window.id)
    }

    fn binding_by_proxy(&self, proxy: &RiverXkbBindingV1) -> Option<(&XKBPrefix, &Binding)> {
        self.prefixes.iter().find(|(_, v)| {
            if let BindingState::Enabled(this) = &v.state {
                this.eq(proxy)
            } else {
                false
            }
        })
    }

    // reconcile_frames ensures that each output gets one maximized Emacs frame.
    fn reconcile_frames(&mut self) {
        let mut frame_requests: usize = 0;

        'outputs: for (output_proxy, output) in &self.outputs {
            if output.width <= 0 || output.height <= 0 {
                log::debug!("waiting for usable dimensions for output");
                continue;
            }
            if let Some(f) = self
                .frames
                .values_mut()
                .find(|f| f.displayed_on.as_ref() == Some(output_proxy))
            {
                let dimensions = (output.width, output.height);
                if f.last_proposed_dimensions != Some(dimensions) {
                    f.proxy.propose_dimensions(dimensions.0, dimensions.1);
                    f.last_proposed_dimensions = Some(dimensions);
                }
                continue;
            }

            // try to find an existing frame that is minimised and reuse it
            for f in self.frames.values_mut() {
                if f.displayed_on.is_some() {
                    continue;
                }

                f.displayed_on = Some(output_proxy.clone());

                // always propose dimensions to keep frame sized to output
                f.proxy.propose_dimensions(output.width, output.height);
                f.last_proposed_dimensions = Some((output.width, output.height));
                f.proxy.inform_maximized();
                f.proxy.set_tiled(Edges::all());
                continue 'outputs;
            }

            // no frame found -> might need a new frame
            frame_requests += 1;
        }

        // Request new frames (if we haven't already fired a request). This
        // accounting is necessary because there might be additional manage
        // sequences before a frame shows up.
        if frame_requests > self.pending_frames {
            for _ in 0..(frame_requests - self.pending_frames) {
                self.send(ToEmacs::RequestFrame);
                self.pending_frames += 1;
            }
        }
    }

    // reconcile_focus updates the seat's focus based on pending_focus (set by
    // events)
    fn reconcile_focus(&mut self) {
        let Some(seat) = &mut self.seat else {
            log::warn!("no seat present, something might have gone wrong");
            return;
        };

        if self.focus.lost_focus() {
            // recover focus by focusing *any* displayed frame
            let Some(frame) = self
                .frames
                .iter()
                .find(|(_, f)| f.displayed_on.is_some())
                .map(|(proxy, _)| proxy.clone())
            else {
                log::error!("no displayed frames -> can not focus anything!");
                return;
            };

            self.focus.focus_frame(frame);
        }

        let is_dirty = self.focus.is_dirty();
        let Some((target, frame)) = self.focus.current_focus_and_frame() else {
            return;
        };

        seat.proxy.focus_window(target);

        if is_dirty {
            if let Some(output) = self
                .frames
                .get(frame)
                .and_then(|frame| frame.displayed_on.as_ref())
                .and_then(|output| self.outputs.get(output))
                && let Some(ls_output) = &output.ls_output
            {
                ls_output.set_default();
            }

            // don't notify emacs about focused frames
            if target != frame
                && let Some(id) = self.window_id(target)
            {
                self.send(ToEmacs::Focused(id));
            }
        }
    }

    // reconcile_windows closes killed windows and removes them from the list
    fn reconcile_windows(&mut self) {
        for (proxy, w) in self.windows.iter_mut() {
            if w.lifecycle.take_close_request() {
                log::info!("requesting window closure");
                proxy.close();
            } else if w.lifecycle.is_active()
                && let Some(params) = &w.params
            {
                if !w.tiled {
                    proxy.set_tiled(Edges::all());
                    w.tiled = true;
                }
                let dimensions = (params.w, params.h);
                if w.last_proposed_dimensions != Some(dimensions) {
                    proxy.propose_dimensions(dimensions.0, dimensions.1);
                    w.last_proposed_dimensions = Some(dimensions);
                }
            }
        }

        // TODO: force kill at some point
    }

    fn reconcile_bindings(&mut self) {
        let mut to_enable = vec![];
        {
            for (_, v) in self.prefixes.iter_mut() {
                if let BindingState::Registered(b) = &v.state {
                    to_enable.push(b.clone());
                    v.state = BindingState::Enabled(b.clone());
                    log::info!("enabling new XKB binding");
                }
            }
        };

        for binding in to_enable.into_iter() {
            binding.enable();
        }
    }

    fn reconcile_fullscreen(&mut self) {
        for output in self.outputs.values_mut() {
            match &output.fullscreen {
                FullscreenState::Requested { new, previous } => {
                    if let Some(previous) = previous {
                        previous.inform_not_fullscreen();
                        previous.exit_fullscreen();
                    }

                    new.inform_fullscreen();
                    new.fullscreen(&output.proxy);
                    output.fullscreen = FullscreenState::Fullscreen(new.clone());
                }
                FullscreenState::Exiting(win) => {
                    win.inform_not_fullscreen();
                    win.exit_fullscreen();
                    output.fullscreen = FullscreenState::None;
                }
                _ => {}
            }
        }
    }

    fn maybe_configure_libinput(
        &mut self,
        proxy: &RiverLibinputDeviceV1,
        qh: &wayland_client::QueueHandle<Self>,
    ) {
        let Some(device) = self.libinput_devices.get_mut(proxy) else {
            return;
        };

        if device.is_touchpad {
            if device.configured_as_touchpad {
                return;
            }
            device.configured_as_touchpad = true;
            configure_touchpad(proxy, self.input_config, qh);
        } else if device.saw_tap_support {
            if device.configured_as_mouse {
                return;
            }
            device.configured_as_mouse = true;
            configure_mouse(proxy, self.input_config, qh);
        }
    }

    fn apply_input_config(&mut self, qh: &wayland_client::QueueHandle<Self>) {
        for (proxy, device) in self.input_devices.iter() {
            if device.kind == InputDeviceKind::Keyboard {
                proxy.set_repeat_info(
                    self.input_config.repeat_rate,
                    self.input_config.repeat_delay,
                );
            }
        }

        let libinput_proxies = self.libinput_devices.keys().cloned().collect::<Vec<_>>();
        for proxy in libinput_proxies {
            if let Some(device) = self.libinput_devices.get_mut(&proxy) {
                device.configured_as_touchpad = false;
                device.configured_as_mouse = false;
            }
            self.maybe_configure_libinput(&proxy, qh);
        }
    }

    fn apply_synced_state(
        &mut self,
        generation: u64,
        parameters: Option<HashMap<u64, WindowParameters>>,
        focus: FocusTarget,
    ) -> bool {
        if !self.state_generation.accept(generation) {
            return false;
        }

        let mut changed = false;
        if let Some(mut new_params) = parameters {
            for window in self.windows.values_mut() {
                let result = new_params.remove(&window.id);
                if window.params != result {
                    window.params = result;
                    changed = true;
                }
            }
        }

        match focus {
            FocusTarget::Window(id) => {
                let Some(window) = self.window_proxy(id) else {
                    log::warn!("ignoring focus request for stale window id {id}");
                    return changed;
                };
                let Some(frame) = self.displaying_frame(&window) else {
                    log::warn!("ignoring focus request for a hidden window");
                    return changed;
                };
                self.focus.focus_window(window, frame.proxy.clone());
                true
            }
            FocusTarget::Frame => {
                self.focus.switch_to_frame();
                true
            }
        }
    }

    fn handle_emacs(&mut self, qh: &wayland_client::QueueHandle<Self>) {
        let mut buf = [0u8; 8];
        match nix::unistd::read(&self.from_emacs, &mut buf) {
            Ok(_) | Err(nix::errno::Errno::EAGAIN) => {}
            Err(err) => {
                log::error!("could not drain Emacs wake event: {err}");
                self.running = false;
                return;
            }
        }

        let mut needs_manage = false;
        let mut pending_state = None;
        loop {
            let msg = match self.rx.try_recv() {
                Ok(msg) => msg,
                Err(std::sync::mpsc::TryRecvError::Empty) => {
                    // Clear after draining, then recheck to close the race with
                    // a producer that observed the old pending state.
                    self.from_emacs_wake_pending.store(false, Ordering::Release);
                    match self.rx.try_recv() {
                        Ok(msg) => {
                            self.from_emacs_wake_pending.store(true, Ordering::Release);
                            msg
                        }
                        Err(std::sync::mpsc::TryRecvError::Empty) => break,
                        Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                            self.running = false;
                            break;
                        }
                    }
                }
                Err(std::sync::mpsc::TryRecvError::Disconnected) => {
                    self.running = false;
                    break;
                }
            };
            match msg {
                FromEmacs::RegisterPrefix(prefix, command) => {
                    needs_manage = true;
                    log::debug!("registering new prefix with command {:?}", command);
                    match self.prefixes.entry(prefix) {
                        std::collections::hash_map::Entry::Occupied(mut entry) => {
                            entry.get_mut().command = command;
                        }
                        std::collections::hash_map::Entry::Vacant(entry) => {
                            entry.insert(Binding {
                                command,
                                state: BindingState::Requested,
                            });
                        }
                    }
                }
                FromEmacs::SetInputConfig(config) => {
                    self.input_config = config;
                    self.apply_input_config(qh);
                }
                FromEmacs::CloseWindow(id) => {
                    let Some(window) = self.window_proxy(id) else {
                        continue;
                    };
                    if let Some(w) = self.windows.get_mut(&window)
                        && w.lifecycle.request_close()
                    {
                        needs_manage = true;
                    }
                }
                FromEmacs::BufferCreated(id) => {
                    let Some(window) = self.window_proxy(id) else {
                        continue;
                    };
                    if let Some(w) = self.windows.get_mut(&window) {
                        needs_manage |= w.lifecycle.buffer_ready();
                    }
                }
                FromEmacs::SyncState {
                    generation,
                    parameters,
                    focus,
                } => {
                    if !self.state_generation.is_newer(generation)
                        || pending_state
                            .as_ref()
                            .is_some_and(|(pending_generation, _, _)| {
                                generation <= *pending_generation
                            })
                    {
                        continue;
                    }
                    let retained_parameters = parameters.or_else(|| {
                        pending_state
                            .take()
                            .and_then(|(_, previous_parameters, _)| previous_parameters)
                    });
                    pending_state = Some((generation, retained_parameters, focus));
                }
                FromEmacs::ExitFullscreen => {
                    let displayed_on = self
                        .focus
                        .current_focus_and_frame()
                        .and_then(|(_, frame)| self.frames.get(frame))
                        .and_then(|frame| frame.displayed_on.clone());
                    if let Some(output) = displayed_on
                        && let Some(output) = self.outputs.get_mut(&output)
                    {
                        let fullscreen = match &output.fullscreen {
                            FullscreenState::Requested { new, .. }
                            | FullscreenState::Fullscreen(new) => Some(new.clone()),
                            _ => None,
                        };
                        if let Some(window) = fullscreen {
                            output.fullscreen = FullscreenState::Exiting(window);
                            needs_manage = true;
                        }
                    }
                }
                FromEmacs::Stop => {
                    if self.stopping {
                        continue;
                    }
                    if let Some(river_wm) = &self.river_wm {
                        self.stopping = true;
                        river_wm.stop();
                    } else {
                        self.running = false;
                    }
                }
                FromEmacs::ExitSession => {
                    if let Some(river_wm) = &self.river_wm {
                        river_wm.exit_session();
                    }
                }
            }
        }

        if let Some((generation, parameters, focus)) = pending_state {
            needs_manage |= self.apply_synced_state(generation, parameters, focus);
        }

        // All commands from Emacs need a manage sequence.
        if let Some(river_wm) = &self.river_wm
            && needs_manage
        {
            river_wm.manage_dirty();
        }

        let register_prefixes = self
            .prefixes
            .iter()
            .filter_map(|(k, v)| match v.state {
                BindingState::Requested => Some(*k),
                _ => None,
            })
            .collect::<Vec<_>>();

        if let (false, Some(xkb), Some(seat)) = (
            register_prefixes.is_empty(),
            self.xkb_bindings.as_ref(),
            self.seat.as_ref(),
        ) {
            let seat = seat.proxy.clone();
            let mut bindings = vec![];

            for p in &register_prefixes {
                let b = xkb.get_xkb_binding(&seat, p.keysym, p.modifiers, qh, ());
                bindings.push(b);
            }

            for (p, b) in register_prefixes.into_iter().zip(bindings) {
                let binding = self
                    .prefixes
                    .get_mut(&p)
                    .expect("binding magically disappeared");
                binding.state = BindingState::Registered(b);
            }
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &wl_registry::WlRegistry,
        event: <wl_registry::WlRegistry as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        {
            if interface == "river_window_manager_v1" {
                let wm =
                    proxy.bind::<RiverWindowManagerV1, _, _>(name, version.min(4), qhandle, ());
                state.river_wm = Some(wm);
                log::debug!("registering river window manager ...");
            } else if interface == "river_xkb_bindings_v1" {
                let xkb = proxy.bind::<RiverXkbBindingsV1, _, _>(name, version.min(2), qhandle, ());
                state.xkb_bindings = Some(xkb);
                log::debug!("registering river xkb bindings ...");
            } else if interface == "river_layer_shell_v1" {
                let layer_shell =
                    proxy.bind::<RiverLayerShellV1, _, _>(name, version.min(1), qhandle, ());
                state.layer_shell = Some(layer_shell);
                log::debug!("registering river layer shell ... ");
            } else if interface == "river_input_manager_v1" {
                let input_manager =
                    proxy.bind::<RiverInputManagerV1, _, _>(name, version.min(1), qhandle, ());
                state.input_manager = Some(input_manager);
                log::debug!("registering river input manager ...");
            } else if interface == "river_libinput_config_v1" {
                let libinput_config =
                    proxy.bind::<RiverLibinputConfigV1, _, _>(name, version.min(1), qhandle, ());
                state.libinput_config = Some(libinput_config);
                log::debug!("registering river libinput config ...");
            }
        }
    }
}

impl Dispatch<RiverWindowManagerV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverWindowManagerV1,
        event: <RiverWindowManagerV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            // manage sequence: window dimensions, fullscreen state, keyboard
            // focus, decorations, capabilities ...
            river::river_window_manager_v1::Event::ManageStart => {
                log::debug!("manage sequence started");

                state.reconcile_frames();
                state.reconcile_windows();
                state.reconcile_bindings();
                state.reconcile_fullscreen();
                state.reconcile_focus();

                proxy.manage_finish();
            }

            // render sequence: positions, z-order, borders, visibility (?), clipping
            river::river_window_manager_v1::Event::RenderStart => {
                // reconcile frame display state
                for (frame_proxy, frame) in state.frames.iter_mut() {
                    let should_show = frame.displayed_on.is_some();
                    if frame.visible != should_show {
                        if should_show {
                            frame_proxy.show();
                        } else {
                            frame_proxy.hide();
                        }
                        frame.visible = should_show;
                    }

                    match frame.displayed_on.as_ref() {
                        None => {}
                        Some(output_proxy) => {
                            frame.node.place_bottom();

                            // position frame at its output's origin
                            if let Some(output) = state.outputs.get(output_proxy) {
                                let position = (output.x, output.y);
                                if frame.last_position != Some(position) {
                                    frame.node.set_position(position.0, position.1);
                                    frame.last_position = Some(position);
                                }
                            }
                        }
                    }
                }

                let frames = &state.frames;
                let outputs = &state.outputs;
                for (win_proxy, window) in state.windows.iter_mut() {
                    let desired_render = window
                        .lifecycle
                        .is_presented()
                        .then_some(())
                        .and(window.params.as_ref())
                        .and_then(|params| {
                            let output = frames
                                .values()
                                .find(|frame| {
                                    frame.name.as_deref() == Some(params.frame_name.as_str())
                                })?
                                .displayed_on
                                .as_ref()
                                .and_then(|output| outputs.get(output))?;
                            let (actual_w, actual_h) =
                                window.actual_width_height.unwrap_or((params.w, params.h));
                            Some((
                                (params.x + output.x, params.y + output.y),
                                (actual_w.min(params.w), actual_h.min(params.h)),
                            ))
                        });

                    if let Some((position, clip)) = desired_render {
                        if !window.visible {
                            win_proxy.show();
                            window.visible = true;
                        }
                        if window.last_position != Some(position) {
                            window.node.set_position(position.0, position.1);
                            window.last_position = Some(position);
                        }
                        window.node.place_top();
                        if window.last_clip != Some(clip) {
                            win_proxy.set_clip_box(0, 0, clip.0, clip.1);
                            window.last_clip = Some(clip);
                        }
                    } else if window.visible {
                        win_proxy.hide();
                        window.visible = false;
                    }
                }

                proxy.render_finish();
            }

            river::river_window_manager_v1::Event::Output { id } => {
                log::debug!("RiverWindowManagerV1::Event::Output received: id={:?}", id);
                let ls_output = state
                    .layer_shell
                    .as_ref()
                    .map(|layer_shell| layer_shell.get_output(&id, qhandle, ()));

                state.outputs.insert(
                    id.clone(),
                    Output {
                        proxy: id,
                        ls_output,
                        x: 0,
                        y: 0,
                        width: 0,
                        height: 0,
                        fullscreen: FullscreenState::None,
                    },
                );
            }

            river::river_window_manager_v1::Event::Seat { id } => {
                log::debug!("RiverWindowManagerV1::Event::Seat received: id={:?}", id);
                let ls_seat = state
                    .layer_shell
                    .as_ref()
                    .map(|layer_shell| layer_shell.get_seat(&id, qhandle, ()));
                if state.seat.is_none() {
                    state.seat = Some(Seat { proxy: id, ls_seat });
                } else {
                    log::error!(
                        "seat is already taken, eureka does not support multi-seats at the moment"
                    );
                }
            }

            river::river_window_manager_v1::Event::Unavailable => {
                state.send(ToEmacs::FatalError(
                    "River window management is unavailable (another window manager may already be running)"
                        .into(),
                ));
                state.running = false;
            }
            river::river_window_manager_v1::Event::Finished => {
                if !state.stopping {
                    state.send(ToEmacs::FatalError(
                        "River unexpectedly stopped the window manager".into(),
                    ));
                }
                state.running = false;
            }
            river::river_window_manager_v1::Event::SessionLocked => {
                log::info!("RiverWindowManagerV1::Event::SessionLocked received");
            }
            river::river_window_manager_v1::Event::SessionUnlocked => {
                log::info!("RiverWindowManagerV1::Event::SessionUnlocked received");
                // TODO: do we still need to recover focus here?
            }
            river::river_window_manager_v1::Event::Window { id } => {
                log::debug!("RiverWindowManagerV1::Event::Window received: id={:?}", id);
                // *not* creating the window object here to avoid Drop complications
            }
        }
    }

    wayland_client::event_created_child!(Eureka, RiverWindowManagerV1, [
        river::river_window_manager_v1::EVT_WINDOW_OPCODE => (river::river_window_v1::RiverWindowV1, ()),
        river::river_window_manager_v1::EVT_OUTPUT_OPCODE => (river::river_output_v1::RiverOutputV1, ()),
        river::river_window_manager_v1::EVT_SEAT_OPCODE => (river::river_seat_v1::RiverSeatV1, ()),
    ]);
}

impl Dispatch<RiverInputManagerV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        _proxy: &RiverInputManagerV1,
        event: <RiverInputManagerV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_input_manager_v1::Event::InputDevice { id } => {
                state.input_devices.insert(
                    id,
                    InputDevice {
                        kind: InputDeviceKind::Unknown,
                    },
                );
            }
            river::river_input_manager_v1::Event::Finished => {}
        }
    }

    wayland_client::event_created_child!(Eureka, RiverInputManagerV1, [
        river::river_input_manager_v1::EVT_INPUT_DEVICE_OPCODE => (river::river_input_device_v1::RiverInputDeviceV1, ()),
    ]);
}

impl Dispatch<RiverInputDeviceV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverInputDeviceV1,
        event: <RiverInputDeviceV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_input_device_v1::Event::Type { _type } => {
                let kind = match _type {
                    WEnum::Value(river::river_input_device_v1::Type::Keyboard) => {
                        proxy.set_repeat_info(
                            state.input_config.repeat_rate,
                            state.input_config.repeat_delay,
                        );
                        InputDeviceKind::Keyboard
                    }
                    WEnum::Value(river::river_input_device_v1::Type::Pointer) => {
                        InputDeviceKind::Pointer
                    }
                    WEnum::Value(river::river_input_device_v1::Type::Touch) => {
                        InputDeviceKind::Touch
                    }
                    WEnum::Value(river::river_input_device_v1::Type::Tablet) => {
                        InputDeviceKind::Tablet
                    }
                    _ => InputDeviceKind::Unknown,
                };

                if let Some(device) = state.input_devices.get_mut(proxy) {
                    device.kind = kind;
                }
            }
            river::river_input_device_v1::Event::Name { name } => {
                log::debug!("input device: {name}");
            }
            river::river_input_device_v1::Event::Removed => {
                state.input_devices.remove(proxy);
            }
        }
    }
}

impl Dispatch<RiverLibinputConfigV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        _proxy: &RiverLibinputConfigV1,
        event: <RiverLibinputConfigV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_libinput_config_v1::Event::LibinputDevice { id } => {
                state.libinput_devices.insert(id, LibinputDevice::default());
            }
            river::river_libinput_config_v1::Event::Finished => {}
        }
    }

    wayland_client::event_created_child!(Eureka, RiverLibinputConfigV1, [
        river::river_libinput_config_v1::EVT_LIBINPUT_DEVICE_OPCODE => (river::river_libinput_device_v1::RiverLibinputDeviceV1, ()),
    ]);
}

impl Dispatch<RiverLibinputDeviceV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverLibinputDeviceV1,
        event: <RiverLibinputDeviceV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_libinput_device_v1::Event::InputDevice { device } => {
                if let Some(libinput) = state.libinput_devices.get_mut(proxy) {
                    libinput.input_device = Some(device);
                }
            }
            river::river_libinput_device_v1::Event::TapSupport { finger_count } => {
                if let Some(libinput) = state.libinput_devices.get_mut(proxy) {
                    libinput.saw_tap_support = true;
                    libinput.is_touchpad = finger_count > 0;
                }
                state.maybe_configure_libinput(proxy, qhandle);
            }
            river::river_libinput_device_v1::Event::Removed => {
                state.libinput_devices.remove(proxy);
            }
            _ => {}
        }
    }

    wayland_client::event_created_child!(Eureka, RiverLibinputDeviceV1, [
        river::river_libinput_device_v1::REQ_SET_SEND_EVENTS_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_TAP_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_TAP_BUTTON_MAP_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_DRAG_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_DRAG_LOCK_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_THREE_FINGER_DRAG_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_CALIBRATION_MATRIX_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_ACCEL_PROFILE_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_ACCEL_SPEED_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_APPLY_ACCEL_CONFIG_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_NATURAL_SCROLL_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_LEFT_HANDED_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_CLICK_METHOD_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_CLICKFINGER_BUTTON_MAP_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_MIDDLE_EMULATION_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_SCROLL_METHOD_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_SCROLL_BUTTON_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_SCROLL_BUTTON_LOCK_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_DWT_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_DWTP_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
        river::river_libinput_device_v1::REQ_SET_ROTATION_OPCODE => (river::river_libinput_result_v1::RiverLibinputResultV1, ()),
    ]);
}

impl Dispatch<RiverLibinputResultV1, ()> for Eureka {
    fn event(
        _state: &mut Self,
        _proxy: &RiverLibinputResultV1,
        event: <RiverLibinputResultV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_libinput_result_v1::Event::Success => log::debug!("setting applied"),
            river::river_libinput_result_v1::Event::Unsupported => {
                log::debug!("setting unsupported")
            }
            river::river_libinput_result_v1::Event::Invalid => log::warn!("setting invalid"),
        }
    }
}

impl Dispatch<wl_output::WlOutput, ()> for Eureka {
    fn event(
        _state: &mut Self,
        _proxy: &wl_output::WlOutput,
        _event: <wl_output::WlOutput as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<RiverOutputV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverOutputV1,
        event: <RiverOutputV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_output_v1::Event::Removed => {
                log::info!("an output was disconnected, removing");
                let Some(_output) = state.outputs.remove(proxy) else {
                    log::warn!("unknown output disconnected");
                    return;
                };

                // River may start another manage sequence before Emacs has
                // destroyed the corresponding frame. Never leave the frame or
                // focus state referring to an output that is no longer in the
                // output map.
                let frame_proxy = state
                    .frames
                    .iter_mut()
                    .find(|(_, frame)| frame.displayed_on.as_ref() == Some(proxy))
                    .map(|(frame_proxy, frame)| {
                        frame.displayed_on = None;
                        frame_proxy.clone()
                    });
                if let Some(frame_proxy) = &frame_proxy {
                    state.focus.invalidate(frame_proxy);
                }

                // A monitor can briefly report itself disconnected when it is
                // powered off and back on.  Keep the last frame around while
                // there are no outputs so reconcile_frames() can reuse it when
                // the output returns.  Deleting it here leaves focus lost and
                // also asks GTK to tear down its sole frame while no monitor
                // exists.  With another output still present, discard the
                // surplus frame as usual so Emacs redistributes its windows.
                if state.outputs.is_empty() {
                    return;
                }

                let Some(frame_name) = frame_proxy
                    .as_ref()
                    .and_then(|proxy| state.frames.get(proxy))
                    .and_then(|frame| frame.name.clone())
                else {
                    log::warn!("disconnected output had no frame");
                    return;
                };

                state.send(ToEmacs::DiscardFrame(frame_name));
            }
            river::river_output_v1::Event::Position { x, y } => {
                log::debug!("output position: x={}, y={}", x, y);
                if let Some(output) = state.outputs.get_mut(proxy) {
                    output.x = x;
                    output.y = y;
                }
            }
            river::river_output_v1::Event::Dimensions { width, height } => {
                log::debug!("output dimensions: {}x{}", width, height);
                if let Some(output) = state.outputs.get_mut(proxy) {
                    output.width = width;
                    output.height = height;
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<RiverLayerShellOutputV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverLayerShellOutputV1,
        event: <RiverLayerShellOutputV1 as wayland_client::Proxy>::Event,
        _: &(),
        _: &Connection,
        _: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_layer_shell_output_v1::Event::NonExclusiveArea {
                x,
                y,
                width,
                height,
            } => {
                let Some(output_proxy) = state
                    .outputs
                    .iter()
                    .find(|(_, o)| o.ls_output.as_ref() == Some(proxy))
                    .map(|(p, _)| p.clone())
                else {
                    log::warn!("could not find matching output for layer-shell output");
                    return;
                };

                if let Some(output) = state.outputs.get_mut(&output_proxy) {
                    output.x = x;
                    output.y = y;
                    output.width = width;
                    output.height = height;
                }
            }
        }
    }
}

impl Dispatch<river::river_seat_v1::RiverSeatV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        _proxy: &river::river_seat_v1::RiverSeatV1,
        event: <river::river_seat_v1::RiverSeatV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        if let river::river_seat_v1::Event::WindowInteraction { window } = event {
            if state.frames.contains_key(&window) {
                state.focus.focus_frame(window);
                return;
            }

            let Some(frame) = state.displaying_frame(&window) else {
                log::error!("received window interaction for window without a frame");
                return;
            };

            state.focus.focus_window(window, frame.proxy.clone());
            state.focus.mark_dirty();
        }
    }
}

impl Dispatch<RiverWindowV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverWindowV1,
        event: <RiverWindowV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        match event {
            river::river_window_v1::Event::UnreliablePid { unreliable_pid } => {
                let node = proxy.get_node(qhandle, ());

                if unreliable_pid == state.pid {
                    log::info!("discovered new Emacs frame ...");
                    state.frames.insert(
                        proxy.clone(),
                        Frame {
                            name: None,
                            displayed_on: None,
                            proxy: proxy.clone(),
                            node,
                            visible: true,
                            last_position: None,
                            last_proposed_dimensions: None,
                        },
                    );

                    if state.pending_frames > 0 {
                        state.pending_frames -= 1;
                    } else {
                        // users might (accidentally?) create new frames
                        log::warn!("new frame was not requested by WM");
                    }
                    return;
                }

                log::info!("discovered new window (PID: {}) ...", unreliable_pid);
                let id = state.next_window_id;
                state.next_window_id = state
                    .next_window_id
                    .checked_add(1)
                    .expect("window id space exhausted");

                state.windows.insert(
                    proxy.clone(),
                    Window {
                        id,
                        proxy: proxy.clone(),
                        node,
                        lifecycle: ClientLifecycle::Discovered,
                        params: None,
                        actual_width_height: None,
                        visible: true,
                        tiled: false,
                        last_position: None,
                        last_clip: None,
                        last_proposed_dimensions: None,
                    },
                );
                state.windows_by_id.insert(id, proxy.clone());
                state.send(ToEmacs::NewWindow(id));
            }
            river::river_window_v1::Event::AppId {
                app_id: Some(app_id),
            } => {
                if app_id.is_empty() {
                    return;
                }

                if let Some(id) = state.window_id(proxy) {
                    state.send(ToEmacs::AppIDChange(id, app_id));
                }
            }
            river::river_window_v1::Event::Title { title: Some(title) } => {
                if title.is_empty() {
                    return;
                }

                if title.starts_with(&state.frame_prefix)
                    && let Some(f) = state.frames.get_mut(proxy)
                {
                    f.name = Some(title);
                    return;
                }

                if let Some(id) = state.window_id(proxy) {
                    state.send(ToEmacs::TitleChange(id, title));
                } else if !state.frames.contains_key(proxy) {
                    log::warn!("received title for unknown window, orphan frame?");
                }
            }
            river::river_window_v1::Event::Dimensions { width, height } => {
                if let Some(w) = state.windows.get_mut(proxy) {
                    w.actual_width_height = Some((width, height));
                }
            }
            river::river_window_v1::Event::Closed => {
                if let Some(id) = state.window_id(proxy) {
                    state.send(ToEmacs::WindowClosed(id));
                    state.windows_by_id.remove(&id);
                }
                state.focus.invalidate(proxy);

                for output in state.outputs.values_mut() {
                    match &output.fullscreen {
                        FullscreenState::Requested { new: win, .. }
                        | FullscreenState::Fullscreen(win)
                        | FullscreenState::Exiting(win)
                            if proxy.eq(win) =>
                        {
                            output.fullscreen = FullscreenState::None;
                        }
                        _ => {}
                    }
                }

                if state.windows.remove(proxy).is_some() {
                    return;
                }

                if state.frames.remove(proxy).is_none() {
                    log::warn!("unknown window closed; eureka bug?");
                }
            }
            river::river_window_v1::Event::MinimizeRequested => {
                if let Some(id) = state.window_id(proxy) {
                    state.send(ToEmacs::MinimizeRequested(id));
                }
            }
            river::river_window_v1::Event::FullscreenRequested { output: target } => {
                // one of the denser pieces of logic here ... figure out which output to fullscreen on:
                // 1. the requested output
                // 2. the output the window is already on
                // 3. the active output
                let potential_target = target
                    .or_else(|| {
                        state
                            .windows
                            .get(proxy)
                            .and_then(|w| w.params.as_ref())
                            .and_then(|p| state.frame_by_name(&p.frame_name))
                            .and_then(|f| f.displayed_on.clone())
                    })
                    .or_else(|| {
                        state
                            .focus
                            .current_focus_and_frame()
                            .and_then(|(_, fw)| state.frames.get(fw))
                            .and_then(|f| f.displayed_on.clone())
                    });
                let Some(target) = potential_target else {
                    log::warn!("fullscreen requested, but could not find matching output!");
                    return;
                };

                if let Some(output) = state.outputs.get_mut(&target) {
                    let previous = match &output.fullscreen {
                        FullscreenState::Fullscreen(window) | FullscreenState::Exiting(window) => {
                            Some(window.clone())
                        }
                        _ => None,
                    };

                    log::debug!("requesting fullscreen state");
                    output.fullscreen = FullscreenState::Requested {
                        new: proxy.clone(),
                        previous,
                    };
                }
            }

            river::river_window_v1::Event::ExitFullscreenRequested => {
                for output in state.outputs.values_mut() {
                    match &output.fullscreen {
                        FullscreenState::Requested { new: current, .. }
                        | FullscreenState::Fullscreen(current)
                            if current.eq(proxy) =>
                        {
                            log::debug!("exiting fullscreen as per request");
                            output.fullscreen = FullscreenState::Exiting(current.clone());
                            return;
                        }
                        _ => {}
                    };
                }
            }
            _ => {}
        }
    }
}

impl Dispatch<RiverXkbBindingV1, ()> for Eureka {
    fn event(
        state: &mut Self,
        proxy: &RiverXkbBindingV1,
        event: <RiverXkbBindingV1 as wayland_client::Proxy>::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &wayland_client::QueueHandle<Self>,
    ) {
        if matches!(event, river::river_xkb_binding_v1::Event::Pressed) {
            let Some((_, binding)) = state.binding_by_proxy(proxy) else {
                log::warn!("received keypress event for unknown binding, eureka bug?");
                return;
            };

            match &binding.command {
                Command::Forward(event) => {
                    state.send(ToEmacs::KeyEvent(event.clone()));
                    state.focus.switch_to_frame();
                }
                Command::ToggleFullscreen => {
                    let Some((focus, frame)) = state.focus.current_focus_and_frame() else {
                        log::warn!("fullscreen requested, but nothing is focused. eureka bug?");
                        return;
                    };

                    if focus == frame {
                        state.send(ToEmacs::Message(
                            "can not fullscreen Emacs even more!".into(),
                        ));
                        return;
                    }

                    let Some(output) = state
                        .frames
                        .get(frame)
                        .and_then(|frame| frame.displayed_on.clone())
                    else {
                        log::warn!("selected frame for fullscreen is not displayed. eureka bug?");
                        return;
                    };

                    let Some(output_state) = state.outputs.get(&output) else {
                        log::warn!("selected output for fullscreen no longer exists");
                        return;
                    };
                    let new_state = match &output_state.fullscreen {
                        FullscreenState::None => FullscreenState::Requested {
                            new: focus.clone(),
                            previous: None,
                        },
                        FullscreenState::Fullscreen(current) => {
                            FullscreenState::Exiting(current.clone())
                        }
                        _ => {
                            log::warn!("invalid output state for fullscreen toggle");
                            return;
                        }
                    };

                    if let Some(output) = state.outputs.get_mut(&output) {
                        output.fullscreen = new_state;
                    }
                }
            }
        }
    }
}

fn configure_touchpad(
    proxy: &RiverLibinputDeviceV1,
    config: RiverInputConfig,
    qh: &wayland_client::QueueHandle<Eureka>,
) {
    let enabled = |value| {
        if value {
            river::river_libinput_device_v1::TapState::Enabled
        } else {
            river::river_libinput_device_v1::TapState::Disabled
        }
    };
    proxy.set_tap(enabled(config.touchpad_tap), qh, ());
    proxy.set_dwt(
        if config.touchpad_disable_while_typing {
            river::river_libinput_device_v1::DwtState::Enabled
        } else {
            river::river_libinput_device_v1::DwtState::Disabled
        },
        qh,
        (),
    );
    proxy.set_dwtp(
        if config.touchpad_disable_while_trackpointing {
            river::river_libinput_device_v1::DwtpState::Enabled
        } else {
            river::river_libinput_device_v1::DwtpState::Disabled
        },
        qh,
        (),
    );
    proxy.set_drag_lock(
        if config.touchpad_drag_lock {
            river::river_libinput_device_v1::DragLockState::EnabledSticky
        } else {
            river::river_libinput_device_v1::DragLockState::Disabled
        },
        qh,
        (),
    );
    proxy.set_natural_scroll(
        if config.touchpad_natural_scroll {
            river::river_libinput_device_v1::NaturalScrollState::Enabled
        } else {
            river::river_libinput_device_v1::NaturalScrollState::Disabled
        },
        qh,
        (),
    );
    proxy.set_accel_speed(f64_array(config.touchpad_accel_speed), qh, ());
    proxy.set_accel_profile(config.touchpad_accel_profile.protocol_value(), qh, ());
    proxy.set_scroll_method(
        if config.touchpad_two_finger_scroll {
            river::river_libinput_device_v1::ScrollMethod::TwoFinger
        } else {
            river::river_libinput_device_v1::ScrollMethod::NoScroll
        },
        qh,
        (),
    );
}

fn configure_mouse(
    proxy: &RiverLibinputDeviceV1,
    config: RiverInputConfig,
    qh: &wayland_client::QueueHandle<Eureka>,
) {
    proxy.set_accel_speed(f64_array(config.mouse_accel_speed), qh, ());
    proxy.set_accel_profile(config.mouse_accel_profile.protocol_value(), qh, ());
}

fn f64_array(value: f64) -> Vec<u8> {
    value.to_ne_bytes().to_vec()
}

dispatch_log_only!(river::river_node_v1::RiverNodeV1);
dispatch_log_only!(river::river_xkb_bindings_v1::RiverXkbBindingsV1);
dispatch_log_only!(river::river_xkb_bindings_seat_v1::RiverXkbBindingsSeatV1);
dispatch_log_only!(RiverLayerShellV1);
dispatch_log_only!(RiverLayerShellSeatV1); // TODO: focus_none? hmm
