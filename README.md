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

## What is in this repository

| Path | What it is |
| --- | --- |
| `english-tv.m3u` | The working channels |
| `penalty-box.m3u` | Channels that failed the last check; they come back when they work again |
| `vlc/` | One-click VLC shortcuts for Windows and Linux |
| `revell-tv/` | The Revell T.V app for Roku |
| `index.html` | The watch page |

Channels come from the public [iptv-org](https://github.com/iptv-org/iptv) list, narrowed down to English. Nothing is hosted here except the lists.
