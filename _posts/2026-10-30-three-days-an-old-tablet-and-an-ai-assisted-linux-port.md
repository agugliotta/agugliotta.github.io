---
layout: post
title: "Three Days, an Old Tablet, and an AI-Assisted Linux Port"
date: 2026-10-30 11:16:42 -0300
category: linux
tags: [linux, homelab, proxmox, reverse-engineering, ai]
---

An old Android tablet became a touchscreen dashboard for my homelab in roughly three days. Getting there involved bootloaders, Linux, reverse engineering, a lot of testing, and an AI coding agent that made the whole project manageable.

The tablet is a Eurocase EUTB_710MDQ with an Allwinner A23 processor, 1 GB of RAM, and a 1024 × 600 screen. Its original software was Android 4.2.2 running a 3.4.39 kernel. The hardware still had potential, but the software was old enough to make it difficult to find a useful role for the device.

I wanted to give it a specific job: sit next to my homelab and show what my Proxmox host was doing. CPU usage, memory, storage, and the state of my virtual machines and containers. A small dedicated display seemed like a good use for a tablet that already had a screen, touch input, and USB.

Before any dashboard could exist, though, we had to get Linux running on the board and make its peripherals work.

That was where AI changed the scale of the project for me.

I used Codex throughout the process to inspect files, work through logs, write build scripts and patches, and turn test results into the next experiment. Tasks that would have required long stretches of research and trial and error became something I could work through in a few days. I would have needed much more time to cover the same ground on my own.

A particularly useful part of the workflow was REA, Reverse Engineer Anything, backed by Ghidra. It gave the AI agent a way to investigate the binaries and kernel modules that came with the tablet.

Those original files contained information we needed. The vendor's display code helped us understand the panel's power-up sequence. The touchscreen driver and configuration helped identify the correct firmware and explain differences in how coordinates were processed. Later, examining the Wi-Fi driver revealed that the stock system loaded calibration data from a board configuration file into memory.

That last detail mattered: detecting the Wi-Fi hardware and seeing nearby networks had not been enough to establish a working connection. Understanding what the original driver did gave us a concrete path to investigate. We eventually got association, DHCP, DNS, and connectivity working with temporary configuration.

REA helped make the stock software readable and searchable. The resulting explanations still needed checking against configuration files, instructions, logs, and the physical device. Some conclusions remained hypotheses, and we kept those distinctions in the notes.

The work progressed through small milestones. We identified the hardware and preserved stock files. We reached Allwinner's FEL boot environment, initialized memory, and booted a Linux 6.12 diagnostic system into a USB shell. From there came the display, touch input, physical buttons, and eventually autonomous boot from microSD.

There were plenty of details to get wrong. A UART pin assignment conflicted with the SD bus. Card detection needed a workaround. Touch orientation and scaling required physical tests. Software restart needed the appropriate kernel support. Each result gave us a smaller, more specific problem to solve next.

I handled the physical side: connecting the tablet, moving the SD card, pressing buttons, and confirming whether the screen, touch input, or audio actually worked. The AI could interpret a log saying that playback had started; I had to tell it whether I heard anything.

Once the Linux base was usable, we built a simple LVGL interface and a Python collector for Proxmox. The collector reads metrics on the host and sends snapshots over a dedicated USB serial channel. A separate USB channel provides the development console. The tablet displays the information without needing Proxmox credentials stored on it.

The installed version boots from microSD into the dashboard. It shows live metrics, offers a scrollable VM/container list with state filters, and provides local tablet restart and shutdown controls. Restarting the tablet through the interface brings the panel back and restores the data connection automatically. Internal NAND was not flashed.

![A rendered preview of the dashboard using demonstration data. The original interface labels are Spanish.](https://raw.githubusercontent.com/agugliotta/tablet-proxmox-panel/main/tools/panel/docs/images/summary.png)

There are unfinished parts. Headphone audio worked, while the built-in speaker remained silent for a reason we have not established. Cameras were never tested. Touch calibration could be improved. Wi-Fi persistence and configuration still need work, as do broader power-management and reliability tests.

I wanted those limits documented alongside the successes. Someone with the same tablet should be able to see what was tested, what failed, and what we simply never tried.

The public repositories now preserve both sides of the project. The Linux repository explains the investigation and includes a Docker-based build that generates a microSD image with one command after the owner supplies two stock board files. The panel repository preserves the application, its collector, and screenshots. Binary redistribution still needs care around the extracted touchscreen firmware, so the documentation explains that boundary too.

For me, the most interesting outcome is how approachable this kind of project became. AI helped connect unfamiliar pieces, carry context between experiments, and keep the work moving. REA gave that process access to evidence buried inside the original software.

In roughly three days, we reached a working use for hardware whose original software had aged out of everyday usefulness. There is more to explore, and now there is a documented starting point for the next person with the same tablet.

The code and research are here:

- [Eurocase EUTB_710MDQ Linux port and bring-up notes](https://github.com/agugliotta/eurocase-eutb710mdq-linux)
- [Tablet Proxmox Panel source archive](https://github.com/agugliotta/tablet-proxmox-panel)
