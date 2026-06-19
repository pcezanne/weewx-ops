# Raspberry Pi Purchase List

Hardware needed to run this stack headlessly, 24/7, with the same reliability guarantees as the macOS setup.

## Core

| Item | Notes |
|------|-------|
| Raspberry Pi 4 Model B (4GB) | 4GB is comfortable; 2GB works but leaves little headroom. Pi 5 is faster but overkill for this workload. |
| Official USB-C Power Supply (15W) | Use the official supply — cheap ones cause undervoltage crashes under load. |
| Case with fan | Pi 4 runs warm at 24/7 load. Argon ONE or any case with active cooling. |

## Storage

Avoid a plain microSD as the primary DB store — SQLite writes constantly and SD cards fail within months under that load.

| Item | Notes |
|------|-------|
| USB SSD (120GB+) | Boot and run everything from USB SSD. Samsung T7 or similar. |
| MicroSD (16GB, for boot only) | Optional: some setups boot from SD, run DB from USB. |

If using microSD for everything, use a **Samsung Pro Endurance** or **SanDisk MAX Endurance** — rated for high write cycles.

## Power Resilience

The Mac has a built-in battery. The Pi does not. A power cut will corrupt an in-progress SQLite write.

| Item | Notes |
|------|-------|
| UPS HAT | Waveshare UPS HAT (C) or PiJuice HAT. Provides clean shutdown on power loss. |
| Or: small UPS (APC BE425M) | Simpler: plug the Pi into a mini UPS. No HAT needed, protects the whole setup including the Ecowitt gateway. |

## Networking

| Item | Notes |
|------|-------|
| Ethernet cable | Prefer wired over WiFi for a headless server. One less failure mode. |

## Optional

| Item | Notes |
|------|-------|
| HDMI micro cable + monitor | Useful for initial setup only. Not needed once SSH is working. |

## Summary

Minimum viable build: Pi 4 4GB + official PSU + Argon ONE case + Samsung T7 SSD + small UPS (~$120–150 total).
