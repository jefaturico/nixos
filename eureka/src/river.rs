// SPDX-License-Identifier: GPL-3.0-or-later

//! Generated River protocol bindings.

pub extern crate wayland_client;
pub use wayland_client::protocol::{wl_output, wl_surface};

mod interfaces {
    pub(super) mod wm {
        pub use wayland_client::protocol::__interfaces::*;
        wayland_scanner::generate_interfaces!("./protocol/river-window-management-v1.xml");
    }

    pub(super) mod xkb {
        use super::wm::*;
        wayland_scanner::generate_interfaces!("./protocol/river-xkb-bindings-v1.xml");
    }

    pub(super) mod layer_shell {
        use super::wm::*;
        wayland_scanner::generate_interfaces!("./protocol/river-layer-shell-v1.xml");
    }

    pub(super) mod input_management {
        use super::wm::*;
        wayland_scanner::generate_interfaces!("./protocol/river-input-management-v1.xml");
    }

    pub(super) mod libinput {
        use super::input_management::*;
        wayland_scanner::generate_interfaces!("./protocol/river-libinput-config-v1.xml");
    }
}

use self::interfaces::input_management::*;
use self::interfaces::layer_shell::*;
use self::interfaces::libinput::*;
use self::interfaces::wm::*;
use self::interfaces::xkb::*;
wayland_scanner::generate_client_code!("./protocol/river-input-management-v1.xml");
wayland_scanner::generate_client_code!("./protocol/river-window-management-v1.xml");
wayland_scanner::generate_client_code!("./protocol/river-xkb-bindings-v1.xml");
wayland_scanner::generate_client_code!("./protocol/river-layer-shell-v1.xml");
wayland_scanner::generate_client_code!("./protocol/river-libinput-config-v1.xml");
