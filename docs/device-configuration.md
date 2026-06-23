# Device Configuration

This document records the configuration observed directly on an Insta360 Luna Ultra running firmware `1.0.47`. Values marked as observed are runtime measurements rather than guaranteed product specifications.

## Identity

| Item | Value |
| --- | --- |
| Product | Insta360 Luna Ultra |
| Internal project | `z03` |
| Hostname | `pineapple` |
| Device tree model | `Qualcomm Technologies, Inc. PineappleP HDK` |
| Machine | `QCS8625_PINEAPPLE` |
| SoC family | Snapdragon |
| SoC ID | `702`, revision `2.0` |
| Architecture | AArch64 |

## Operating system

| Item | Value |
| --- | --- |
| Distribution | QTI Linux robotics platform, performance build |
| Distribution build | `Z03_V0.9.2015-19-g510af52254` |
| Kernel | `6.1.128-android14-11-maybe-dirty-perf` |
| Init system | systemd |
| Root filesystem | ext4, read-only |
| Writable system state | overlayfs backed by `/dev/sda22` |
| SELinux | Permissive |
| Root shell context | `system_u:system_r:initrc_t:s0-s15:c0.c1023` |
| Root ADB context | `system_u:system_r:unconfined_t:s0-s15:c0.c1023` |

The boot command line selects slot A:

```text
root=/dev/sda17
systemd.setenv="SLOT_SUFFIX=_a"
androidboot.project_stage=MP1
androidboot.baseband=apq
```

## CPU

The platform exposes eight ARMv8 cores in four frequency policies.

| CPUs | ARM part ID | Frequency range |
| --- | --- | --- |
| 0-1 | `0xD80` | 364.8 MHz to 2.2656 GHz |
| 2-4 | `0xD81` | 499.2 MHz to 3.1488 GHz |
| 5-6 | `0xD81` | 499.2 MHz to 2.9568 GHz |
| 7 | `0xD82` | 480 MHz to 3.3024 GHz |

The available governors are `walt`, `conservative`, `powersave`, `performance`, and `schedutil`. The observed governor was `walt`.

## Memory

| Item | Value |
| --- | --- |
| Installed class | 6 GB |
| Linux-visible memory | 5,702,292 KiB, approximately 5.44 GiB |
| zram swap | 2,851,144 KiB, approximately 2.72 GiB |

## GPU and media acceleration

- Qualcomm Adreno graphics stack.
- Exact Adreno marketing model is not exposed by the available sysfs nodes.
- Qualcomm DRM, EGL, GLES, and Vulkan libraries are installed.
- Qualcomm VIDC exposes `/dev/video32` and `/dev/video33` for hardware video processing.
- Qualcomm camera modules include ISP, ICP, JPEG, CSIPHY, and request-manager components.

## Camera subsystem

The production media configuration names the image sensor as:

```text
OV50H40
```

Observed camera topology:

- Two camera sensor subdevices.
- Two actuator subdevices.
- Two EEPROM subdevices.
- Six CSI PHY subdevices.
- Qualcomm Camera Request Manager, ISP, ICP, JPEG, and VIDC nodes.
- Separate Wide and Tele calibration packages.

Calibration files:

```text
/ins/calib/camera/Z03_WIDE_OTP_Module.bin
/ins/calib/camera/Z03_TELE_OTP_Module.bin
```

Primary media configuration:

```text
/ins/etc/ins_mediad/ins_media_stream_prd.json
```

## Display and subordinate processors

| Item | Value |
| --- | --- |
| Internal panel | DSI command-mode panel |
| Resolution | 318 x 564 |
| Refresh rate | 60 Hz |
| Screen processor | V851, updated by `Z03_RD.bin` |
| Screen MCU | `Z03_RM`, version `0.9.2` on firmware 1.0.47 |
| Main MCU | `Z03_GM`, version `1.0.0` on firmware 1.0.47 |

## Storage

The main storage is UFS. Linux exposes approximately 56.7 GiB of raw capacity, consistent with a nominal 64 GB device.

| Mount or purpose | Device | Size or notes |
| --- | --- | --- |
| Root filesystem, slot A | `/dev/sda17` | 2.9 GiB, read-only, 94% used when measured |
| Root filesystem, slot B | `/dev/sda18` | 3 GiB partition |
| Writable overlay | `/dev/sda22` | 2.9 GiB |
| Internal media | `/dev/sda23` | 47.0 GiB exFAT at `/ins/media_rw/emulated` |
| Camera calibration | `/dev/sda6` | 56 MiB at `/ins/calib/camera` |
| Calibration backup | `/dev/sda7` | 56 MiB at `/ins/calib/camera_bak` |
| Firmware state | `/dev/sda19` | 56 MiB at `/ins/firmware` |
| Wi-Fi calibration | `/dev/sda21` | mounted at `/ins/calib/wifi` |
| DSP | `/dev/sde11` | 59 MiB at `/dsp` |
| Qualcomm firmware | `/dev/sde6` | approximately 450 MiB at `/firmware` |
| microSD observed during analysis | `/dev/mmcblk1p1` | 238.2 GiB exFAT at `/mnt/sdcard` |

The device has A/B boot, DSP, DTBO, and other Qualcomm firmware partitions. Camera calibration and settings also have explicit backup partitions.

## Battery and power

The battery model string identifies a two-cell 4,244 mAh lithium-ion pack.

Observed snapshot during analysis:

| Item | Value |
| --- | --- |
| State | Discharging |
| Capacity | 66% |
| Voltage | 8.156 V |
| Current | approximately -658 mA |
| Battery temperature | 24 degrees C |

Observed thermal ranges under the analysis workload:

| Sensor group | Temperature |
| --- | --- |
| CPU | approximately 63 to 72 degrees C |
| GPU | approximately 60 to 61 degrees C |
| Skin sensor | approximately 62.6 degrees C |

## Peripheral devices

Notable I2C and platform devices:

| Device | Purpose |
| --- | --- |
| `MAX31760` | Fan controller |
| `CW2217` | Battery fuel gauge |
| `WCD939x` | Qualcomm audio codec |
| `FS16xx` | Audio amplifier |

## Wireless networking

| Item | Value |
| --- | --- |
| Wi-Fi vendor | Broadcom, PCI ID `14e4:4362` |
| Driver family | `bcmdhd` |
| Client interface | `wlan0` |
| Camera AP interface | `wlan1` |
| Camera AP address | `192.168.42.1/24` |
| Observed SSID | `Luna Ultra TMJ6NM.OSC` |

## Exposed network services

| Address | Service | Process | Notes |
| --- | --- | --- | --- |
| `0.0.0.0:22/tcp` | Root SSH | Dropbear | Key-only custom service |
| `0.0.0.0:80/tcp` | HTTP | nginx | Media paths require camera authorization |
| `0.0.0.0:5555/tcp` | Root ADB | adbd | Authentication disabled by the custom service |
| `:::6666/tcp` | Camera control | `ins_link` | Private binary protocol, begins with `UCD2` traffic |
| `0.0.0.0:23456/tcp` | GUI/debug bridge | `ins_gui` | `INSGUI` traffic and developer actions |
| `0.0.0.0:61234/tcp` | HTTPS | nginx | Root request returns HTTP 204 |
| `127.0.0.1:8080/tcp` | Internal HTTP | `ins_httpd` | Loopback only |
| `127.0.0.1:61235/tcp` | Internal MTA | `ins_mta` | Loopback only |
| `0.0.0.0:67/udp` | DHCP | dnsmasq | Camera AP DHCP server |
| `0.0.0.0:6000/udp` | Internal proxy | `ins_rs_proxy` | Proprietary traffic |
| `0.0.0.0:6002/udp` | Internal proxy | `ins_rs_proxy` | Proprietary traffic |

The TLS certificate on port `61234` is an Insta360 self-signed RSA-2048 certificate with subject CN `192.168.43.1`.

## Developer-mode findings

Developer mode caused `ins_gui` to publish this action on TCP port `23456`:

```text
DeveloperExecuteCommand_Action:
/ins/etc/ins_gui/json/developer_mode_init.sh
```

The command path was observed running with UID 0 and SELinux domain `initrc_t`. The GUI bridge accepted client-to-BLL action forwarding without authentication. This behavior was used only on an owner-controlled camera to establish the initial temporary root shell.

## Firmware container

Analyzed package:

```text
Insta360LunaUltraFW-C42D99D4ENC-V1.0.47.bin
```

| Item | Value |
| --- | --- |
| Size | 1,772,480,176 bytes |
| SHA-256 | `3592284B5AD38D9D25E0ECF187560B80B1F7D1B2A5946F17B1F2772D4FC1B85A` |
| Container magic | `MWFI` |
| Container format | 1 |
| Product | `z03` |
| Firmware version | `1.0.47` |
| Container entries | 7 |

The large payload sections have high entropy and do not expose plaintext ext4, EROFS, SquashFS, Android boot, or UBI signatures. The tail contains authentication data and a 256-byte block consistent with an RSA-2048 signature. The exact signature interpretation remains an inference.

## Installed firmware components

The camera records the following `1.0.47` update components in `/ins/firmware/ins_otad/otad_version.json`:

| Priority | Component | Method | Version | SHA-256 |
| --- | --- | --- | --- | --- |
| 1 | `Z03_RD.bin` | `slave_screen_v851` | `1.0.47` | `f1df0f09baae126a53385531dbc3041721dccc48a9ae8d6bc76d39771e3edc5e` |
| 2 | `Z03_RM-V0.9.2-5666f06d.bin` | `slave_screen_mcu` | `0.9.2` | `6032d0e9130b0fc731cba644dc0e0d109fafc23a146ffb2a5c00794af307c512` |
| 3 | `Z03_GM-V1.0.0-9a35d986.bin` | `slave_main_mcu` | `1.0.0` | `cd3f60d5fefa6f11807e80c573ac1eb4735c0d5a80bfdec9b51f89876efc1ba0` |
| 4 | `qcs8625_ota.zip` | `host_8625` | `1.0.47` | `9ee352b86006bb708b576bea82753df29ee54096fb1f8113e1ca54d92eaf192e` |
| 5 | `Insta360LunaUltraFW-EB-0F613A1E.bin` | `backup` | `1.0.6` | `4fc8a45844c3914bebd50db77c4f218179a2b360b7cbfd1f7b351687e41925ee` |

Recorded OTA history includes versions `0.7.147`, `0.7.261`, `1.0.11`, and `1.0.47`.
