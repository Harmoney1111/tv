# Revell T.V

Free English-language TV channels, each one checked to be working when the list was last updated.

**Watch page:** https://harmoney1111.github.io/tv/

## Watch with VLC

1. Install [VLC media player](https://www.videolan.org/vlc/) (free, for Windows, Mac, Linux, phones and tablets).
2. Open the channels:
   - **Windows:** download [`vlc/Revell-TV.bat`](https://harmoney1111.github.io/tv/vlc/Revell-TV.bat) and double-click it.
   - **Linux:** save [`vlc/revell-tv.desktop`](vlc/revell-tv.desktop) into `~/.local/share/applications`.
   - **Anything else:** in VLC choose *Open Network Stream* and paste
     `https://harmoney1111.github.io/tv/english-tv.m3u`
3. Press <kbd>Ctrl</kbd>+<kbd>L</kbd> for the channel list and double-click a channel.

The shortcuts read the list from the web every time, so they always open the newest version.

## Ad skip (Roku and Ubuntu Touch apps)

Many free channels mark their ad breaks in the stream, and most Pluto TV channels do. During a marked break the apps switch to a channel you choose (MTV Biggest Pop unless you pick another) and come back when the break is over.

- **Roku:** press Play on any channel in the list to use it during ads. During a break, press Back and pick the channel again to return to the show early.
- **Ubuntu Touch:** tap the gear at the top, then *Channel during ads*. During a break, tap *Back now* to return early.

## Watching on the Roku

- **OK** on a channel watches it full screen; **Up / Down** change channel.
- **Back** while watching keeps the channel playing in a window beside the list, also during an ad break. Pick the same channel again for full screen (during a break this also ends the break early); Back on the menu stops it.
- **\*** on a channel in the list saves it. (While video plays, only Back, Up and Down reach the app; the Roku keeps the other buttons for itself.)

## What is in this repository

| Path | What it is |
| --- | --- |
| `english-tv.m3u` | The working channels |
| `penalty-box.m3u` | Channels that failed the last check; they come back when they work again |
| `vlc/` | One-click VLC shortcuts for Windows and Linux |
| `revell-tv/` | The Revell T.V app for Roku |
| `ubuntu-touch/` | The Revell T.V app for Ubuntu Touch phones (`install-on-phone.sh` installs it over USB with developer mode on) |
| `index.html` | The watch page |

Channels come from the public [iptv-org](https://github.com/iptv-org/iptv) list, narrowed down to English. Nothing is hosted here except the lists.
