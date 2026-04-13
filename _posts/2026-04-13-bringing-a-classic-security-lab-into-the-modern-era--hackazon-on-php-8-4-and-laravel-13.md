---
layout: post
title: "Bringing a Classic Security Lab into the Modern Era: Hackazon on PHP 8.4 and Laravel 13"
date: 2026-04-13 15:24:49
category: security
tags: [hackazon, laravel, php, security, docker]
---

I had a problem. I wanted to run a hands-on web security lab for a group of students, and Hackazon was the obvious choice — it's the best intentionally vulnerable app out there for teaching real OWASP attack patterns in a realistic context. Full e-commerce shell, covers SQLi, XSS, CSRF, IDOR, RFI, XXE, command injection. It's genuinely good.

The catch: it runs on PHP 5.4 and PHPixie. PHPixie. A framework with about 400 GitHub stars that hasn't had a commit in years.

Getting it running in 2025 meant wrestling with ancient runtimes, fighting Docker images that barely exist, and watching it silently fail on any modern Linux distro. I spent a few hours trying. Then I decided to just port it.

## The Rule I Had to Tattoo on My Brain

Before touching a single line of code, I had to internalize one thing: **the bugs are the features.**

Every raw `echo $_GET['q']`, every string-interpolated SQL query, every missing CSRF token — that's not technical debt. That's the curriculum. The moment I let muscle memory kick in and "fixed" a sloppy query with a prepared statement, I'd silently break the lab for everyone using it.

This made the migration genuinely harder than a normal port. I couldn't just mechanically translate PHPixie idioms to Laravel idioms. I had to read every controller, understand *why* it was wrong, and then carry that wrongness carefully into the new codebase. It required a different kind of attention.

## Bringing Claude Into the Loop

I'll be straight: I did this migration with Claude. Not as a "prompt and pray" thing — more like pair programming with an AI that had read every Laravel doc and could hold the full context of a controller in its head while I explained what the vulnerability was supposed to do. 

The workflow was iterative and, honestly, messy. I'd paste a PHPixie controller, explain the vulnerability model, and ask for a Laravel equivalent that preserved the badness. Claude would produce something. I'd read it, spot where it had instinctively sanitized input or swapped a raw query for the query builder, push back, and we'd go another round. Some controllers took three or four iterations before the logic was right *and* the vulnerability was intact.

The more interesting pattern: Claude was actually good at flagging *accidental* fixes. A few times it'd note something like "I've used `htmlspecialchars` here, but if the stored XSS is intentional, you'll want to remove that." That kind of awareness saved me from subtle regressions I would have caught much later during testing.

Would I have gotten here without it? Eventually, yes. Faster? Definitely yes.

## The VulnInjection System

Hackazon has a runtime toggle system that lets you enable or disable each vulnerability per controller action. It's clever — the same endpoint can behave securely or insecurely depending on a config value, which is great for showing students the before/after without deploying two separate apps.

The original is built around a custom PHPixie service. I rewrote it as a Laravel Service Provider that registers a `VulnInjector` singleton. Controllers pull it from the container and call `->isVulnerable('sqli', 'product_search')` before deciding whether to sanitize. Straightforward to port in principle; annoying in practice because I had to map every action name from the PHPixie convention to the Laravel route names, and some of the original naming was... creative.

The admin UI for editing these toggles existed in the original codebase mostly as a stub. I built it out fully — a simple Blade UI that reads and writes the vuln config, with a table per vulnerability class. Nothing fancy, but it works and students actually need it.

## The 61-Route Crawl

After the initial port compiled and booted without errors, I had no idea which routes actually worked. So I wrote a quick script to crawl all 61 routes, log HTTP status codes, and dump stack traces for 500s. That became the punch list.

Most failures were mundane: namespace mismatches, missing variables being passed to views, PHPixie helper functions that don't exist in Laravel. A few were more interesting — cases where the 500 was itself part of the vulnerability path, and I'd accidentally made the error handling too robust.

Running through that list systematically, iteration by iteration, is the most tedious part of any port. There's no shortcut. You just work through it.

## Packaging It for Class

The Docker setup is a standard PHP-FPM + Nginx + MySQL compose stack, nothing exotic. The one thing worth calling out is the database reset script. Between lab sessions you want a clean slate — fresh seed data, no leftover payloads from the previous student's XSS practice. The script drops and re-seeds the schema, and takes about ten seconds. `docker compose up` gets the whole thing running in under two minutes on a decent machine.

That two-minute spin-up is what I actually cared about. Students lose enough time on environment setup. Keeping that friction minimal matters.

## What I'd Do Differently

A few things I'd change on a second pass:

**The route-to-vuln-config mapping is fragile.** Right now, if you rename a route, the VulnInjector silently fails open (secure by default, actually fine for a lab, but still not great). A smarter approach would be attribute-based — a `#[Vulnerable('sqli')]` attribute on the controller method that the service reads at runtime.

**Some of the legacy endpoints are held together with string and hope.** The AMF and GWT endpoints work, but they're vendored libraries wired in via manual bootstrapping. If PHP 8.x deprecates something they depend on, it'll break quietly. I'd add at least smoke-test coverage for those routes in CI.

**I should have committed more granularly during the port.** Working with Claude across many iterations meant I often had large, mixed diffs by the time I'd verified a controller was working correctly. Harder to review, harder to roll back a specific decision.

## The Repo

The result is a fully functional, Docker-ready Hackazon on PHP 8.4 / Laravel 13. All the documented vulnerabilities are verified: the SQLi in product search and login, stored XSS in profiles, IDOR on order access, CSRF on account settings, command injection in the network diagnostics widget.

The code is on [GitHub](https://github.com/agugliotta/hackazon). It's not polished — it's a security lab, and parts of it are deliberately terrible. But it runs, it teaches, and a Laravel developer can actually read it.

---

If you've done something similar — porting a legacy app while deliberately preserving its flaws — I'd genuinely like to hear how you approached it. And if you've used an LLM for this kind of migration work before, I'm curious whether your experience with the back-and-forth iteration matched mine. Drop a comment below.
