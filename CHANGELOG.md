# Changelog

All notable changes to this project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.3.0.0] - 2026-09-28 - First Public Release - Beta

### Added
- `Install-ClickOnceApplication`: silent installation from a URL or UNC path via `InPlaceHostingManager`,
  with status/exit code result object, timeout, optional `-Launch` and `-Silent`.
- `Uninstall-ClickOnceApplication`: silent uninstallation with tab completion for `-Name` and two methods:
  - `Direct` (default): dialog-free, imitates the ClickOnce uninstaller (files, shortcuts, component store,
    "Apps & features" entry); supports `-WhatIf`; stops with exit code 11 if other installed applications share the
    publisher key (override with `-Force`). Based on Wunder.ClickOnceUninstaller (MIT), see `THIRD-PARTY-NOTICES.md`.
  - `Dialog`: automates the official ClickOnce maintenance dialog.
- `Get-ClickOnceApplication`: lists the ClickOnce applications installed for the current user (incl. public key token).
- `Write-Progress` based progress display (suppressed by `-Silent`).
- Transparent PowerShell 7 support: the installation is executed in Windows PowerShell 5.1.
- Comment-based help for all public functions.
