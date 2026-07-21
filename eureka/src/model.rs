// SPDX-License-Identifier: GPL-3.0-or-later

//! Small, protocol-independent pieces of Eureka's desktop state.
//!
//! Keep this module free of Wayland and Emacs types.  These transitions are the
//! user-visible rules that should remain easy to test and understand.

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum ClientLifecycle {
    Discovered,
    Active,
    CloseRequested,
    Closing,
}

impl ClientLifecycle {
    pub(crate) fn buffer_ready(&mut self) -> bool {
        if *self != Self::Discovered {
            return false;
        }
        *self = Self::Active;
        true
    }

    pub(crate) fn request_close(&mut self) -> bool {
        if *self == Self::CloseRequested {
            return false;
        }
        *self = Self::CloseRequested;
        true
    }

    pub(crate) fn take_close_request(&mut self) -> bool {
        if *self != Self::CloseRequested {
            return false;
        }
        *self = Self::Closing;
        true
    }

    pub(crate) fn is_active(self) -> bool {
        self == Self::Active
    }

    pub(crate) fn is_presented(self) -> bool {
        self != Self::Discovered
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum FocusTarget {
    Frame,
    Window(u64),
}

#[derive(Debug, Default)]
pub(crate) struct Generation {
    current: u64,
}

impl Generation {
    pub(crate) fn is_newer(&self, candidate: u64) -> bool {
        candidate > self.current
    }

    pub(crate) fn accept(&mut self, candidate: u64) -> bool {
        if !self.is_newer(candidate) {
            return false;
        }
        self.current = candidate;
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lifecycle_follows_confirmed_transitions() {
        let mut lifecycle = ClientLifecycle::Discovered;
        assert!(lifecycle.buffer_ready());
        assert_eq!(lifecycle, ClientLifecycle::Active);
        assert!(lifecycle.request_close());
        assert_eq!(lifecycle, ClientLifecycle::CloseRequested);
        assert!(lifecycle.take_close_request());
        assert_eq!(lifecycle, ClientLifecycle::Closing);
    }

    #[test]
    fn lifecycle_coalesces_pending_close_and_allows_retry() {
        let mut lifecycle = ClientLifecycle::Discovered;
        assert!(lifecycle.request_close());
        assert!(!lifecycle.request_close());
        assert!(!lifecycle.buffer_ready());
        assert!(lifecycle.take_close_request());
        assert!(!lifecycle.take_close_request());
        assert!(lifecycle.request_close());
        assert_eq!(lifecycle, ClientLifecycle::CloseRequested);
        assert!(lifecycle.take_close_request());
    }

    #[test]
    fn generation_only_accepts_newer_state() {
        let mut generation = Generation::default();
        assert!(generation.accept(1));
        assert!(!generation.accept(1));
        assert!(!generation.accept(0));
        assert!(generation.accept(3));
        assert!(!generation.accept(2));
    }
}
