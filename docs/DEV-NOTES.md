# MacBlox 0.2.3 — macOS Roblox account manager

Native SwiftUI app for macOS 14+. The supplied executable is for Apple Silicon. Intel users can build from source on an Intel Mac with Swift 6 and Xcode command line tools. Ad-hoc signed development release; not notarized for public distribution.

## Install/update

Quit MacBlox, unzip MacBlox-0.2.3.zip, and replace the old app. Move MacBlox.app into Applications and open it. Existing saved accounts remain in macOS Keychain. Install the official Roblox.app in /Applications before launching games.

## Account selection and organization

- Command-click or Shift-click accounts to select multiple alts.
- Select visible selects the current group/search/favorites result. Clear deselects all.
- Account setup saves aliases, group names, favorites, per-account game/server destinations, and notes automatically.
- Select several accounts to assign a group or destination to the whole selection.
- Group picker, favorites filter, and search narrow the sidebar. Launch selected respects the selection. Launch all accounts includes all saved real accounts, regardless of the sidebar filter.
- Demo alt adds another fictional profile; demo accounts cannot launch and are not saved to Keychain.
- Hide names conceals account labels, activity messages, and the profile editor. It does not obscure Roblox windows or prevent users opening the login sheet.

## Three launch modes

**Same game**: enter a game link or numeric place ID. Roblox chooses a public server independently for each alt.

**Same public server**: enter a game, then paste a server Job ID (UUID), or click Find public servers and choose one. Pick room for selection picks the first listed server with enough current free slots for the selected real accounts. This browser reads the first 100 public server listings; it does not reserve space. Full/closing servers or Roblox access restrictions can prevent joining.

**Per-account destinations**: uses each alt's saved game link and optional Job ID from Account setup. Assign the same game and Job ID to one group and a different destination to another group, then launch them together. Empty Job ID lets Roblox select a server. Missing or invalid destinations stop queue creation before any accounts launch.

Private-server share links and following an arbitrary player into their server are not implemented.

## Queue and clients

- Launch selected or Launch all accounts starts a serial queue.
- Skip accounts already running avoids duplicate launches.
- Continue after an account fails is optional; default behavior stops on an error.
- Bring each client to front controls foreground activation.
- Extra launch delay adds 0–30 seconds between clients after the existing startup wait.
- Pause and Stop queue take effect after the current launch finishes; neither closes existing clients.
- Queue & activity shows per-account outcomes and up to 200 in-memory activity entries. No cookies or launch tickets are logged.
- Running refreshes every two seconds, shows managed process IDs, and has Focus/Close controls. Close all managed requests normal quit from every managed client. It does not target your regular Roblox app.
- Destination presets save a launch mode and shared game/server destination. Per-account assignments are saved separately.

## Performance

Choose Roblox default, 60, 120, 144, or 240 FPS in Performance, then click Apply FPS limit while all Roblox Player clients are closed. This edits only FramerateCap in the latest existing GlobalBasicSettings_<version>.xml and saves an original-file backup beside it. Restore original settings restores that whole backup. Unknown XML formats are rejected without writing.

This preference is global, not per-account. Roblox may reset or ignore it after updates. A cap is a target, not an achieved frame-rate guarantee. Graphics quality remains configurable inside Roblox.

## Sessions and client behavior

Each Add account sheet uses a temporary WebKit session for Roblox's own login and verification. After Save account, the session is validated against Roblox and saved in macOS Keychain. Passwords are not read or saved. Cookies are sent only to Roblox's authenticated-user and ticket endpoints over HTTPS; redirects are rejected on those requests. Removing an account deletes its saved session from this manager, but does not revoke it on Roblox. Use Roblox security settings to revoke sessions.

Each account gets an APFS copy of the installed client in ~/Library/Application Support/MacBlox/Clients. It has a separate bundle identifier, LSMultipleInstancesProhibited=false, and an ad-hoc signature preserving client entitlements. The launch URL is delivered to that specific app through NSWorkspace. The named /RobloxPlayerUniq semaphore is unlinked before starting the next client. The installed Roblox.app is left intact.

Client copies share some Roblox preference files and machine identity. Do not assume complete filesystem isolation. Client copies remain after an account is removed. The user confirmed concurrent launching on the prior version; this release retains that URL-handler mechanism. Roblox updates can still change compatibility. “Client open” reports a running process, not a verified game connection or username.

## Build and checks

```sh
./script/build_and_run.sh
```

Build-only: `./script/build_and_run.sh --build`. Other options: --verify, --debug, --logs, --telemetry. The script stages/signs outside iCloud-managed Documents metadata, creates the app ZIP beside the source folder, then copies the app there too. If Finder metadata affects the copied bundle, use the ZIP and unpack it into Applications.

The app executable supports `--self-test`: it checks shared/exact server URL routing, destination and Job ID validation, FPS XML preservation/rejection, and profile serialization without accessing accounts, network, or Roblox settings. `--demo` opens with three fictional accounts selected.

Validation for 0.2: compilation, ad-hoc signature verification, self-checks, and process startup passed. Interactive GUI automation could not complete because the desktop computer-use connection was closed. New server-target and FPS features have not been verified inside a live game. The XCTest target requires full Xcode; XCTest is unavailable in this machine's Command Line Tools installation.

Implementation references:
- https://github.com/TrapstarKS/TrapRAM
- https://github.com/estevanhernandez-stack-ed/rororo-mac

Not affiliated with Roblox.

## 0.2.1 tracking fix

Running status and duplicate-launch checks now use kernel process IDs and the actual executable path inside the per-account Clients folder, rather than cached app bundle identifiers. This also finds clients that do not appear in the macOS app list and recovers them after restarting MacBlox. Exited/zombie processes are excluded. Focus and Close recheck process ownership before acting. A regression check launches two disposable local fixture processes, detects both distinct account paths, then verifies that exiting one removes only that account. All self-checks and signature verification passed. Live Roblox-account behavior still needs user confirmation.

## 0.2.2 updater restart tracking

Live inspection found that Roblox updated a client and restarted it from Clients/Roblox.app instead of the account-named bundle. New launches now use Clients/<account ID>/Roblox.app, so updater restarts retain an identifiable parent folder. The queue follows replacement PIDs for up to 60 seconds and requires eight seconds of stable, finished startup. Legacy unassigned Clients/Roblox.app processes appear as Unassigned client rather than being attributed to a guessed account; relaunch the account with this version to restore its account label. Old numeric .app layouts remain recognized. A native disposable-process integration check passed for two simultaneous account folders, replacing one PID, and removing only the exited account. No live Roblox sessions were launched for that test.

## 0.2.3 app icon

Added a native blue stacked-tile icon, a complete macOS iconset packaged as Resources/MacBlox.icns, and CFBundleIconFile metadata. The build script copies it before code signing. The editable generator is script/generate_icon.swift. No launcher or account behavior changed.

## v1.1.0 private invites

Private server mode and per-account game fields now accept long Roblox private links and Server share links. Share invites resolve through Roblox sharelinks with the selected account session and CSRF retry. Long links resolve their access UUID from the authenticated game page. Resolution errors stop that account, with no fallback to public matchmaking. Invite links in destination presets and account profiles are stored in local UserDefaults; do not treat those preferences as an encrypted vault. Resolved access codes are kept only for the launch request. No real invite is included in tests, logs, or the repository. The launch path retains existing client isolation/tracking behavior. Tests use synthetic API/HTML responses. Live private gameplay still needs validation with an account that has permission.
