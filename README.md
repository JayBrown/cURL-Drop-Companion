# cURL Drop Companion

**macOS companion application (Platypus with z-shell script) for [`curldrop`](https://github.com/kennell/curldrop)to share files on your Mac with other users in the local network or over the internet via direct download links.**

Why? Because **AirDrop** only works between Apple devices, and few people have installed **[`wormhole`](https://github.com/magic-wormhole/magic-wormhole)** or **[SyncThing](https://syncthing.net/)**.

CDC is meant as an ad-hoc sharing solution, i.e. to only launch the `curldrop` sharing server when you actually want to share files with someone, and then stop the server again. However, you have the option to persist the `curldrop` server for either local or local & remote sharing using the CDC startup configuration. If you are looking for your own permanent solution to keep the sharing server running, you should persist `curldrop` by default at log-in, e.g. with a macOS LaunchAgent. (See below for full persistence.)

*Note:* the current release is at v1.0.3, but it has not been tested thoroughly, and only on macOS 11.2 (Big Sur).

## Requisites
* **[`curldrop`](https://github.com/kennell/curldrop)** (install with `python3` using `pip3`)
* **[`detox`](http://detox.sourceforge.net/)** (install e.g. with [Homebrew](https://brew.sh))
* **[`imagemagick`](https://www.imagemagick.org/)** (install e.g. with Homebrew)
* **[`miniupnpc`](https://miniupnp.tuxfamily.org/)** (install e.g. with Homebrew)
* **`python3`** (install e.g. with **Xcode**, the **Apple Command Line Tools**, or Homebrew etc.)
* **[`qrencode`](https://fukuchi.org/works/qrencode/index.html.en)** (install e.g. with Homebrew)

## Optional dependencies
* **[`sendEmail`](https://github.com/mogaal/sendemail)** (install e.g. with Homebrew)
* **[`terminal-share`](https://github.com/mattt/terminal-share)** (install with `ruby` using `gem`)

## Install
* Download the DMG of the **[latest release](https://github.com/JayBrown/cURL-Drop-Companion/releases/latest)**
* dequarantine
* copy app into any of your applications folders
* double-click the workflow to install the Finder Quick Action 

## Setup
### TCC
* allow app to control your Mac (you might be asked several times)
* allow notifications

### Configuration
* configure the basic network, sharing & persistence settings
* optional: configure `sendEmail` settings (enter admin password to store credentials in your keychain)

## Functionality
* select files for sharing or send files to CDC (Finder Quick Action included)
* select local or remote sharing
* curldrop server will be started on localhost using the relevant ports (by default 8000 for local network sharing & 4747 for remote sharing)
* the remote sharing port will be automatically opened as a redirect on your router/AP; if the router/AP is not supported or accessible, then you can only share files locally
* file sharing information (domain-based download link, IP-based download link, file size, file hash) will always be copied to the pasteboard and written to an info file into the user-defined curldrop sharing folder
* file information (together with QR code based on the sharing URL) can be shared using the following options:

### Sharing options
* sendEmail (background e-mail service)
* new message in Apple Mail
* new message in Apple Messages
* QR code display
* print

### Notes
* leave the curldrop server running until the shared files have been downloaded
* stop the server (and if necessary close the redirect ports on your router/AP) by launching CDC without input and choosing "Clear Server" from the startup options
* you can persist the `curldrop` server independent of any of CDC's persistence settings by touching a `.persist` dotfile in your `curldrop` sharing directory
* if you start your `curldrop` server externally, e.g. with a LaunchAgent, you must ensure that CDC's network settings are in accordance
* a verbose log file is written to `/tmp/local.lcars.cURLDropCompanion.log`

## Known bugs
* Sometimes the `curldrop` server will simply stop for unknown reasons immediately after CDC ends, so I assume it has something to do with the latter. An attempt to fix this by adding a sleep time of 3 seconds after a successful share was added in v1.0.4.

## To-do
—
 
## Uninstall
* delete the main application and the user-defined curldrop sharing folder
* delete the cURL Drop Companion keychain entry containing the `sendEmail` credentials
* delete `~/Library/Caches/local.lcars.cURLDropCompanion`
* delete `~/Library/Preferences/local.lcars.cURLDropCompanion.plist`
* delete `~/Library/Services/cURL Drop Companion.workflow`
