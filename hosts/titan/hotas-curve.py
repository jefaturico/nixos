#!/usr/bin/env python3
"""Expose the T.Flight HOTAS X through a curved virtual evdev device."""

from __future__ import annotations

import logging
import select
import signal
import sys
import time

from evdev import AbsInfo, InputDevice, UInput, ecodes, list_devices


VENDOR = 0x044F
PRODUCT = 0xB108
VIRTUAL_PHYS = "elite-hotas-curve/input0"
CURVED_AXES = {ecodes.ABS_X, ecodes.ABS_Y, ecodes.ABS_RZ}
# Cubic response passing through the user's previous positive-side control
# point (input=0.5, output=0.25):
#   (1 - expo) * 0.5 + expo * 0.5**3 = 0.25
EXPO = 2.0 / 3.0
RECONNECT_DELAY = 1.0

log = logging.getLogger("elite-hotas-curve")
stopping = False


def curve(value: int, axis: AbsInfo) -> int:
    """Apply a cubic-expo curve without a software deadzone."""
    half_range = (axis.max - axis.min) / 2
    if half_range <= 0:
        return value

    midpoint = axis.min + half_range
    normalized = max(-1.0, min(1.0, (value - midpoint) / half_range))
    curved = (1 - EXPO) * normalized + EXPO * normalized**3
    output = round(midpoint + curved * half_range)
    return max(axis.min, min(axis.max, output))


def find_physical_hotas() -> InputDevice | None:
    for path in list_devices():
        try:
            device = InputDevice(path)
        except OSError:
            continue

        if (
            device.info.vendor == VENDOR
            and device.info.product == PRODUCT
            and device.phys != VIRTUAL_PHYS
        ):
            return device
        device.close()
    return None


def seed_axis_state(device: InputDevice, virtual: UInput, axes: dict[int, AbsInfo]) -> None:
    # uinput axes otherwise begin at zero, which is an extreme for this HOTAS.
    for code, axis in axes.items():
        value = device.absinfo(code).value
        if code in CURVED_AXES:
            value = curve(value, axis)
        virtual.write(ecodes.EV_ABS, code, value)
    virtual.syn()


def forward(device: InputDevice) -> None:
    axes = dict(device.capabilities(absinfo=True).get(ecodes.EV_ABS, []))
    missing = CURVED_AXES.difference(axes)
    if missing:
        raise RuntimeError(f"HOTAS is missing expected axes: {sorted(missing)}")

    virtual = UInput.from_device(
        device,
        filtered_types=(ecodes.EV_SYN, ecodes.EV_FF),
        name=device.name,
        vendor=device.info.vendor,
        product=device.info.product,
        version=device.info.version,
        bustype=device.info.bustype,
        phys=VIRTUAL_PHYS,
    )

    try:
        device.grab()
        seed_axis_state(device, virtual, axes)
        log.info(
            "forwarding %s (%04x:%04x) from %s to %s",
            device.name,
            device.info.vendor,
            device.info.product,
            device.path,
            virtual.device.path if virtual.device else "uinput",
        )

        while not stopping:
            readable, _, _ = select.select([device.fd], [], [], 1.0)
            if not readable:
                continue

            for event in device.read():
                if event.type == ecodes.EV_SYN:
                    if event.code == ecodes.SYN_REPORT:
                        virtual.syn()
                    elif event.code == ecodes.SYN_DROPPED:
                        seed_axis_state(device, virtual, axes)
                    continue

                if event.type == ecodes.EV_FF:
                    continue

                value = event.value
                if event.type == ecodes.EV_ABS and event.code in CURVED_AXES:
                    value = curve(value, axes[event.code])
                virtual.write(event.type, event.code, value)
    finally:
        try:
            device.ungrab()
        except OSError:
            pass
        virtual.close()


def stop(_signum: int, _frame: object) -> None:
    global stopping
    stopping = True


def self_test() -> None:
    axis = AbsInfo(value=0, min=0, max=1023, fuzz=0, flat=0, resolution=0)
    assert curve(0, axis) == 0
    assert curve(1023, axis) == 1023
    assert curve(512, axis) in (511, 512)
    assert 512 < curve(522, axis) < 522
    # Half travel from center maps to one-quarter output, matching the former
    # cubic-spline control point (0.5, 0.25), within integer-axis rounding.
    assert 638 <= curve(767, axis) <= 640
    print("curve self-test passed")


def main() -> int:
    if "--self-test" in sys.argv:
        self_test()
        return 0

    logging.basicConfig(level=logging.INFO, format="%(name)s: %(message)s")
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)

    while not stopping:
        device = find_physical_hotas()
        if device is None:
            log.info("waiting for T.Flight HOTAS X (%04x:%04x)", VENDOR, PRODUCT)
            time.sleep(RECONNECT_DELAY)
            continue

        try:
            forward(device)
        except (OSError, RuntimeError) as error:
            if not stopping:
                log.warning("device unavailable: %s; reconnecting", error)
        finally:
            device.close()

        if not stopping:
            time.sleep(RECONNECT_DELAY)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
