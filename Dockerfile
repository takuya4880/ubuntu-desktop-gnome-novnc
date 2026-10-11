FROM ubuntu:resolute

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnome-core gnome-session-flashback tigervnc-standalone-server tigervnc-tools \
    novnc websockify dbus-x11 tini curl x11-utils \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 1001 --shell /bin/bash desktop \
    && ln -s vnc.html /usr/share/novnc/index.html

COPY docker/entrypoint.sh /usr/local/bin/desktop-entrypoint
COPY docker/session.sh /usr/local/bin/desktop-session
RUN chmod 755 /usr/local/bin/desktop-entrypoint /usr/local/bin/desktop-session \
    && mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
USER desktop
WORKDIR /home/desktop
ENV DISPLAY=:1 DESKTOP_RESOLUTION=1920x1080
EXPOSE 6080
HEALTHCHECK --interval=15s --timeout=5s --start-period=60s \
    CMD curl -fsS http://127.0.0.1:6080/vnc.html >/dev/null && xdpyinfo -display :1 >/dev/null || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/desktop-entrypoint"]
