---
layout: post
title: "Bringing a Classic Security Lab into the Modern Era: Hackazon on PHP 8.4 and Laravel 13"
date: 2026-04-13 15:24:49
category: security
tags: [hackazon, laravel, php, security, docker]
---

Rapid7's Hackazon is one of the best intentionally vulnerable web applications for teaching real-world attack techniques. It covers the full OWASP Top 10 in a realistic e-commerce shell: SQLi, XSS, CSRF, IDOR, RFI, XXE, OS Command Injection — all live, all exploitable, all documented. The problem is that it ran on PHP 5.4 and PHPixie, a micro-framework that never reached mainstream adoption. By 2025, standing it up required ancient runtimes, broke on any modern Linux distro, and was genuinely painful to set up for a class of students.

So I ported it.

## The Constraint That Made It Hard

The central challenge of this migration wasn't technical — it was philosophical. **Vulnerabilities are the product, not bugs.** Every place the original code deliberately skipped sanitization, used string-concatenated SQL, or echoed raw user input without escaping had to stay exactly that way. Touching those lines without understanding *why* they were wrong would silently fix the lab.

That meant reading every controller before porting it. Not for performance or style — to identify which bad practices were intentional and which were just PHPixie idioms. The two look surprisingly similar.

## The Work

**Framework port (~40 controllers, 15+ models):** PHPixie's MVC maps cleanly to Laravel's, but the conventions diverge in the details. PHPixie uses a custom `$this->db->query()` for raw SQL; Laravel has Eloquent and the query builder. For clean code I'd use the query builder. For the lab, raw `DB::statement()` with string-interpolated user input was the right call — that's what makes the SQLi work.

**Preserving VulnInjection:** The original Hackazon includes a runtime toggle system that enables or disables each vulnerability per controller action. Think of it as a feature flag system where the flags control whether the app is broken or not. I ported this as a Laravel Service Provider that binds a `VulnInjector` singleton to the container. Controllers resolve it via dependency injection and call `->isEnabled('sqli', 'account')` before deciding whether to sanitize input. The admin UI for editing these toggles — stubbed and non-functional in a previous Laravel migration attempt — is fully built out.

**Legacy endpoints:** Hackazon includes AMF/Flash and GWT endpoints alongside a REST API, because it was designed to cover every attack surface a real application might expose. Keeping these alive meant vendoring the relevant libraries and wiring them into Laravel's router manually, outside the standard Eloquent/Blade stack.

**The 61-route crawl:** After the initial port compiled and booted, every route worked or returned a 500. I wrote a script to crawl all 61 routes, log the HTTP status, and record the stack trace for each failure. That became the punch list. Most errors were namespace mismatches, missing view data, or PHPixie helpers that had no Laravel equivalent. A handful were subtler — places where the error itself was the vulnerability and I'd accidentally made the code too defensive.

**Docker Compose setup:** The final piece was packaging it for classroom use. The compose file brings up PHP 8.4 (FPM), Nginx, and MySQL, with a database reset script that drops and re-seeds the schema between lab sessions. `docker compose up` and it's ready in under two minutes.

## The Outcome

The result is a fully functional, Docker-ready security lab on a maintainable stack. Every documented vulnerability in the original Hackazon has been verified to work post-migration: the SQLi in the product search and login flows, the stored XSS in user profiles, the IDOR in order access, the CSRF on account settings, the command injection in the network diagnostics widget.

The codebase is now something a Laravel developer can read and work with, which also makes it more useful as a teaching artifact — students can look at the controller code, understand *why* it's vulnerable, and trace the fix without needing to know anything about PHPixie.

The repository is available on [GitHub](https://github.com/agugliotta/hackazon).
