# Ubuntu GNOME noVNC desktop

A browser-accessible desktop based on `ubuntu:resolute` (Ubuntu 26.04), with
`gnome-core`, GNOME Flashback, TigerVNC, and noVNC installed.
The desktop session is **GNOME Flashback (Metacity / X11)**. This image does
not run a Wayland GNOME Shell session. Docker and Docker Compose are required.
The publication workflow targets `linux/amd64`.
Flashback components start directly under a private D-Bus session, without
systemd or a login manager. System-level desktop features such as power
management and the usual GNOME logout workflow are not provided; use Docker
to stop the desktop.

## Run locally

```bash
docker build -t takuya4880/ubuntu-desktop-gnome-novnc:latest .
mkdir -p .secrets
chmod 700 .secrets
read -rsp 'VNC password (6–8 characters): ' password; echo
printf '%s' "$password" > .secrets/vnc_password.txt
unset password
chmod 644 .secrets/vnc_password.txt
docker compose up -d
```

Open `http://localhost:6080/` in your browser, select Connect, and enter your
password. Once the image is published on Docker Hub, use
`docker compose pull && docker compose up -d --no-build` to run that image.
Stop the desktop with `docker compose down`. Home directory changes are lost
when the container is removed.

Set `DESKTOP_RESOLUTION` to change the screen size (default: `1280x800`).
Either `VNC_PASSWORD_FILE` or `VNC_PASSWORD` is required. Passwords must contain
6–8 characters because classic VNC authentication only uses eight characters.
TigerVNC listens exclusively on localhost:5901 inside the container.
noVNC serves HTTP; use an HTTPS reverse proxy with access authentication for
remote access. The supplied Compose configuration binds only to the host's
loopback address. The desktop runs as a non-root user.
The private `.secrets` directory protects the password on the host; the file
must be readable by the non-root user when mounted as a Compose secret.

## Validate

```bash
docker build -t desktop:test .
bash tests/smoke.sh desktop:test
```

The smoke test checks the GNOME panel, Metacity, the X display, the noVNC page,
and a VNC protocol greeting through the actual WebSocket bridge. It also
opens GNOME Calculator and checks that its window is visible.

## Publish with GitHub Actions

In the GitHub repository, open **Settings → Secrets and variables → Actions →
Secrets → New repository secret** and create these repository secrets:

| Name | Value |
| --- | --- |
| `DOCKERHUB_USERNAME` | `takuya4880` |
| `DOCKERHUB_TOKEN` | A Docker Hub access token with write access to the image repository |

A push to `main`, a `v*` tag push, or a manual workflow run builds and smoke-tests
the image before publishing to `takuya4880/ubuntu-desktop-gnome-novnc`.
Pull requests build and test without publishing.
The default branch produces `latest`, tag pushes produce the tag name, and
all publications include a `sha-*` tag. Set the repository's default branch
to `main`.
