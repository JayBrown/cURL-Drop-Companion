# cURL Drop Companion

**macOS companion application (Platypus with z-shell script) for `curldrop` to share files on your Mac with other users in the local network or over the internet via direct download links.**

Why? Because **AirDrop** only works between Macs, and not everyone has installed `wormhole`.

CDC is meant as an ad-hoc sharing solution, i.e. to only launch the service if you quickly want to share files with someone. If you are looking for a permanent solution to keep a sharing server running, you should persist `curldrop` by default at log-in, e.g. with a macOS LaunchAgent.

*Note:* the current release is at v1.0.1, but it has not been tested thoroughly, and only on macOS 11.2 (Big Sur).

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
* allow app to control your Mac
* configure the network settings
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
* Leave the curldrop server running until the shared files have been downloaded
* Stop the server (and if necessary close the redirect ports on your router/AP) by launching CDC without input and choosing "Clear Server" from the startup options
* a verbose log file is written to `/tmp/local.lcars.cURLDropCompanion.log`
 
## Uninstall
* delete the main application and the user-defined curldrop sharing folder
* delete the cURL Drop Companion keychain entry
* delete `~/Library/Preferences/local.lcars.cURLDropCompanion.plist`
* delete `~/Library/Services/cURL Drop Companion.workflow`
