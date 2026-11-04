# Navinix companion

A small FastAPI service that runs on the Navidrome server. The app's **Add**
tab sends it a YouTube link; it checks the link, downloads the audio with
yt-dlp, converts it to MP3 with ffmpeg, tags it (title, artist, album artist,
album = title, square cover art) and saves it into the Navidrome music folder,
then asks Navidrome to rescan.

For personal use. The token is the only protection: keep the service on your
LAN (or behind a VPN) and don't expose it to the internet.

## API

Everything except `/health` needs `Authorization: Bearer <COMPANION_TOKEN>`.
Errors are `{"error": "message", "code": "..."}` (`unauthorized` 401,
`invalid_link` 422, `already_exists` 409, `not_found` 404).

| Call | Returns |
|---|---|
| `GET /health` | `{version, ytDlpVersion}` |
| `POST /validate {url}` | `{valid, videoId, title, channel, durationSeconds, thumbnailUrl, parsed:{artist, albumArtist, title}, alreadyExists}` |
| `POST /download {url, force?}` | `{jobId}`. 409 if the file exists and `force` isn't true |
| `GET /jobs/{id}` | `{status: queued\|downloading\|converting\|tagging\|done\|failed, progress, error, file, warning}` |

Only `youtube.com`, `www.`, `m.`, `music.youtube.com` and `youtu.be` links to a
single video are accepted. A `watch?v=…&list=…` link is treated as the one
video; a bare playlist link is refused.

**Quality:** MP3, 320 kbit/s constant bitrate. (For V0 instead, set
`MP3_ARGS = ["-q:a", "0"]` in `app/media.py`.)

**File name:** `<Artist> - <Title>.mp3` (characters not allowed in file names
are dropped). **Each song is its own single:** album = song title, album
artist = the first artist of a collab.

**Title parsing** (`app/parser.py`): split at the first ` - ` (left = artist,
right = song); with no ` - ` the channel name (minus ` - Topic`) is the
artist. In the song, everything from the first of `(` `[` `*` `＊` `|` `–` `—`
is cut, except a trailing `(pt. N)` / `(part N)`. Album artist = the first
name when splitting the artist on ` & `, `, `, ` x `, ` feat. `, ` ft. `.

## Install (Debian 13)

```sh
# 1. Packages. ffmpeg converts; python3-venv for the service.
sudo apt install -y ffmpeg python3-venv pipx curl unzip

# 2. A service user that can write to the music folder.
sudo useradd --system --create-home --home-dir /opt/navinix-companion --shell /usr/sbin/nologin navinix
ls -ld /opt/navidrome/music          # who owns it?
```

### Write access to `/opt/navidrome/music` (the usual snag)

The `navinix` user must be able to **create files** in the music folder, and
Navidrome must be able to **read** them. The simplest way is a shared group:

```sh
sudo groupadd -f music
sudo usermod -aG music navinix
sudo usermod -aG music navidrome            # the user Navidrome runs as
sudo chgrp -R music /opt/navidrome/music
sudo chmod -R g+rwX /opt/navidrome/music
sudo find /opt/navidrome/music -type d -exec chmod g+s {} +   # new files inherit the group
sudo systemctl restart navidrome
```

If you'd rather not touch groups: `sudo setfacl -R -m u:navinix:rwX -d -m u:navinix:rwX /opt/navidrome/music`.
Check with `sudo -u navinix touch /opt/navidrome/music/.test && sudo rm /opt/navidrome/music/.test`.
The unit's `ReadWritePaths=` must name your actual music folder.

### yt-dlp: use an absolute path (pipx and PATH)

A `pipx` install lives in the *installing user's* home (`~/.local/bin`), which a
system service doesn't have on its `PATH` and can't read. So install it for the
service user into a fixed place and call it **by absolute path**:

```sh
sudo -u navinix env PIPX_HOME=/opt/navinix-companion/pipx PIPX_BIN_DIR=/opt/navinix-companion/bin \
    pipx install yt-dlp
/opt/navinix-companion/bin/yt-dlp --version
```

Set `YT_DLP_PATH=/opt/navinix-companion/bin/yt-dlp` in the env file. (If you
leave it blank the service runs `python -m yt_dlp` from its own virtualenv,
which needs the `yt-dlp` package from `requirements.txt`.) Don't rely on the
`yt-dlp` in your own shell's `PATH`.

### Deno (YouTube extraction needs a JavaScript runtime)

Recent yt-dlp needs a JS runtime to solve YouTube's challenges, otherwise
downloads fail with "Sign in to confirm you're not a bot" or missing formats.

```sh
curl -fsSL https://deno.land/install.sh | sudo DENO_INSTALL=/usr/local sh
deno --version          # /usr/local/bin/deno
```

Set `DENO_PATH=/usr/local/bin/deno`; the service passes it to yt-dlp
(`--js-runtimes deno:…`).

### Keep yt-dlp updated

YouTube changes often and old versions break. Update regularly:

```sh
sudo -u navinix env PIPX_HOME=/opt/navinix-companion/pipx PIPX_BIN_DIR=/opt/navinix-companion/bin \
    pipx upgrade yt-dlp
```

Automate it, for example `/etc/cron.weekly/yt-dlp-update` with the line above
(prefix `#!/bin/sh`). `GET /health` shows the running version. When downloads
suddenly fail, update first.

### The service

```sh
sudo mkdir -p /opt/navinix-companion/app
sudo cp -r companion/app companion/requirements.txt /opt/navinix-companion/app/
sudo python3 -m venv /opt/navinix-companion/venv
sudo /opt/navinix-companion/venv/bin/pip install -r /opt/navinix-companion/app/requirements.txt
sudo chown -R navinix:navinix /opt/navinix-companion

sudo cp companion/companion.env.example /etc/navinix-companion.env
sudo nano /etc/navinix-companion.env          # token, paths, Navidrome login
sudo chown root:navinix /etc/navinix-companion.env && sudo chmod 640 /etc/navinix-companion.env

sudo cp companion/navinix-companion.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now navinix-companion
curl http://localhost:8787/health
journalctl -u navinix-companion -f
```

(The `app` package is copied to `/opt/navinix-companion/app/app`; the unit's
`WorkingDirectory` is the folder that contains it.) In the app: **Add** tab →
address `http://<server-ip>:8787`, your token → **Test connection** → Save.

## Configuration

| Variable | |
|---|---|
| `COMPANION_TOKEN` | required, 16+ characters |
| `MUSIC_DIR` | required, must be writable |
| `NAVIDROME_URL`, `NAVIDROME_USER`, `NAVIDROME_PASSWORD` | rescan; without them a warning is shown instead |
| `YT_DLP_PATH` | absolute path to yt-dlp (else `python -m yt_dlp`) |
| `DENO_PATH` | absolute path to deno |
| `FFMPEG_PATH` | default `ffmpeg` on `PATH` |
| `WORK_DIR` | temp downloads (default system temp) |

A failed rescan never fails a job: the file is saved and the app shows a
warning. Jobs run one at a time and are kept in memory (lost on restart).

## Tests

```sh
cd companion
python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest
```

yt-dlp, ffmpeg and Navidrome are mocked; nothing touches the network.
