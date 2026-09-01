#!/usr/bin/env bash

set -Eeuo pipefail

echo "============================================================"
echo "             WAYDROID UBUNTU SETUP"
echo "============================================================"

export DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

ANDROID_USER="${ANDROID_USER:-android}"
APK_PATH="${APK_PATH:-}"

echo "[1/10] Detecting system..."
echo

echo "OS:"
cat /etc/os-release || true

echo
echo "Kernel:"
uname -a

echo
echo "Architecture:"
uname -m

# ------------------------------------------------------------
# ROOT CHECK
# ------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script with sudo/root."
    exit 1
fi

# ------------------------------------------------------------
# KERNEL / WAYDROID REQUIREMENTS CHECK
# ------------------------------------------------------------

echo
echo "[2/10] Checking kernel support..."

BINDER_FOUND=0

if [ -e /dev/binderfs ]; then
    echo "[OK] /dev/binderfs exists"
    BINDER_FOUND=1
fi

if [ -e /dev/binder ]; then
    echo "[OK] /dev/binder exists"
    BINDER_FOUND=1
fi

if mount | grep -qi binder; then
    echo "[OK] Binder filesystem is mounted"
    BINDER_FOUND=1
fi

echo
echo "Binder devices:"
find /dev -maxdepth 2 -iname '*binder*' -print 2>/dev/null || true

echo
echo "Ashmem:"
if [ -e /dev/ashmem ]; then
    echo "[OK] /dev/ashmem exists"
else
    echo "[INFO] /dev/ashmem not present"
fi

echo
echo "KVM:"
if [ -e /dev/kvm ]; then
    echo "[OK] /dev/kvm exists"
else
    echo "[INFO] /dev/kvm not present"
fi

# ------------------------------------------------------------
# UPDATE SYSTEM
# ------------------------------------------------------------

echo
echo "[3/10] Updating Ubuntu..."

apt-get update

# ------------------------------------------------------------
# INSTALL DEPENDENCIES
# ------------------------------------------------------------

echo
echo "[4/10] Installing Waydroid dependencies..."

apt-get install -y \
    curl \
    ca-certificates \
    lxc \
    python3 \
    python3-gi \
    python3-dbus \
    gir1.2-gtk-3.0 \
    dbus \
    dbus-x11 \
    policykit-1 \
    polkitd \
    iptables \
    iproute2 \
    bridge-utils \
    uidmap \
    wget \
    unzip \
    jq \
    psmisc \
    procps \
    mesa-utils \
    weston \
    wayland-utils \
    xwayland

# ------------------------------------------------------------
# WAYLAND SUPPORT
# ------------------------------------------------------------

echo
echo "[5/10] Preparing Wayland environment..."

mkdir -p /run/user

if id "$ANDROID_USER" >/dev/null 2>&1; then
    USER_UID="$(id -u "$ANDROID_USER")"

    mkdir -p "/run/user/$USER_UID"

    chown "$ANDROID_USER:$ANDROID_USER" \
        "/run/user/$USER_UID"

    chmod 700 "/run/user/$USER_UID"

    echo "ANDROID_USER=$ANDROID_USER"
    echo "USER_UID=$USER_UID"
else
    echo "[INFO] User '$ANDROID_USER' does not exist yet."
fi

# ------------------------------------------------------------
# INSTALL WAYDROID REPOSITORY
# ------------------------------------------------------------

echo
echo "[6/10] Adding official Waydroid repository..."

if ! command -v waydroid >/dev/null 2>&1; then

    curl -fsSL https://repo.waydro.id | bash

    apt-get update

    apt-get install -y waydroid

else

    echo "[OK] Waydroid already installed."

fi

echo
echo "Waydroid version:"
waydroid --version || true

# ------------------------------------------------------------
# CREATE USER
# ------------------------------------------------------------

echo
echo "[7/10] Preparing Android user..."

if ! id "$ANDROID_USER" >/dev/null 2>&1; then

    useradd \
        --create-home \
        --shell /bin/bash \
        "$ANDROID_USER"

fi

USER_UID="$(id -u "$ANDROID_USER")"
USER_HOME="$(getent passwd "$ANDROID_USER" | cut -d: -f6)"

mkdir -p "/run/user/$USER_UID"

chown "$ANDROID_USER:$ANDROID_USER" \
    "/run/user/$USER_UID"

chmod 700 "/run/user/$USER_UID"

echo "User: $ANDROID_USER"
echo "UID:  $USER_UID"
echo "HOME: $USER_HOME"

# ------------------------------------------------------------
# D-BUS
# ------------------------------------------------------------

echo
echo "[8/10] Preparing D-Bus..."

if command -v dbus-launch >/dev/null 2>&1; then
    echo "[OK] dbus-launch available"
else
    echo "[WARN] dbus-launch unavailable"
fi

# ------------------------------------------------------------
# WAYDROID INITIALIZATION
# ------------------------------------------------------------

echo
echo "[9/10] Initializing Waydroid..."

if [ ! -d /var/lib/waydroid/images ] || \
   [ -z "$(find /var/lib/waydroid/images -type f 2>/dev/null | head -n 1)" ]; then

    echo "Waydroid images not found."
    echo "Downloading official Waydroid images..."

    waydroid init

else

    echo "[OK] Existing Waydroid images detected."

fi

# ------------------------------------------------------------
# WAYDROID PROPERTIES
# ------------------------------------------------------------

echo
echo "Configuring Waydroid..."

waydroid prop set persist.waydroid.multi_windows true || true

waydroid prop set persist.waydroid.width 1280 || true

waydroid prop set persist.waydroid.height 720 || true

# ------------------------------------------------------------
# CONTAINER
# ------------------------------------------------------------

echo
echo "Starting Waydroid container..."

waydroid container start || true

sleep 8

echo
echo "Waydroid status after container start:"
waydroid status || true

# ------------------------------------------------------------
# WAYLAND SESSION
# ------------------------------------------------------------

echo
echo "============================================================"
echo " IMPORTANT: Waydroid session must run as normal user"
echo "============================================================"

SESSION_SCRIPT="/tmp/start-waydroid-session.sh"

cat > "$SESSION_SCRIPT" <<EOF
#!/usr/bin/env bash

set -Eeuo pipefail

export HOME="$USER_HOME"
export USER="$ANDROID_USER"
export LOGNAME="$ANDROID_USER"

export XDG_RUNTIME_DIR="/run/user/$USER_UID"

mkdir -p "\$XDG_RUNTIME_DIR"

chmod 700 "\$XDG_RUNTIME_DIR"

export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=Wayland
export WAYLAND_DISPLAY=wayland-0

echo "Starting Waydroid session..."

waydroid session start
EOF

chmod +x "$SESSION_SCRIPT"

chown "$ANDROID_USER:$ANDROID_USER" "$SESSION_SCRIPT"

# ------------------------------------------------------------
# START SESSION
# ------------------------------------------------------------

echo
echo "Starting Waydroid session as $ANDROID_USER..."

set +e

sudo -u "$ANDROID_USER" \
    env \
    HOME="$USER_HOME" \
    USER="$ANDROID_USER" \
    LOGNAME="$ANDROID_USER" \
    XDG_RUNTIME_DIR="/run/user/$USER_UID" \
    XDG_SESSION_TYPE=wayland \
    XDG_CURRENT_DESKTOP=Wayland \
    WAYLAND_DISPLAY=wayland-0 \
    bash "$SESSION_SCRIPT" \
    > /tmp/waydroid-session.log 2>&1 &

SESSION_PID=$!

set -e

echo "Session PID: $SESSION_PID"

# ------------------------------------------------------------
# WAIT FOR ANDROID
# ------------------------------------------------------------

echo
echo "Waiting for Android..."

ANDROID_READY=0

for i in $(seq 1 60); do

    sleep 2

    STATUS="$(waydroid status 2>&1 || true)"

    echo "[$i/60]"
    echo "$STATUS"

    if echo "$STATUS" | grep -qi "Session.*RUNNING"; then
        ANDROID_READY=1
        break
    fi

    if echo "$STATUS" | grep -qi "RUNNING"; then
        ANDROID_READY=1
        break
    fi

done

# ------------------------------------------------------------
# RESULT
# ------------------------------------------------------------

echo
echo "============================================================"
echo "              WAYDROID STATUS"
echo "============================================================"

waydroid status || true

echo
echo "Session log:"
tail -100 /tmp/waydroid-session.log || true

if [ "$ANDROID_READY" -ne 1 ]; then

    echo
    echo "============================================================"
    echo " WAYDROID SESSION DID NOT BECOME READY"
    echo "============================================================"

    echo
    echo "Possible causes:"
    echo "1. GitHub runner kernel does not provide required Binder support."
    echo "2. No Wayland compositor is available."
    echo "3. Container failed to start."
    echo "4. Session is being started outside a graphical Wayland session."
    echo "5. Runner/VM virtualization limitations."

    echo
    echo "Kernel:"
    uname -a

    echo
    echo "Binder:"
    find /dev -maxdepth 2 -iname '*binder*' -print 2>/dev/null || true

    echo
    echo "Container:"
    waydroid status || true

    echo
    echo "Waydroid log:"
    waydroid log -n 150 || true

    echo
    echo "Session log:"
    cat /tmp/waydroid-session.log || true

    exit 1

fi

# ------------------------------------------------------------
# APK INSTALL
# ------------------------------------------------------------

echo
echo "============================================================"
echo "                  APK INSTALL"
echo "============================================================"

if [ -n "$APK_PATH" ] && [ -f "$APK_PATH" ]; then

    echo "Installing APK:"
    echo "$APK_PATH"

    chown "$ANDROID_USER:$ANDROID_USER" "$APK_PATH"

    sudo -u "$ANDROID_USER" \
        env \
        HOME="$USER_HOME" \
        USER="$ANDROID_USER" \
        XDG_RUNTIME_DIR="/run/user/$USER_UID" \
        waydroid app install "$APK_PATH"

    echo
    echo "Installed applications:"
    sudo -u "$ANDROID_USER" \
        env \
        HOME="$USER_HOME" \
        XDG_RUNTIME_DIR="/run/user/$USER_UID" \
        waydroid app list

else

    echo "[INFO] No APK specified."

    echo
    echo "To install manually:"
    echo
    echo "waydroid app install /path/to/app.apk"

fi

# ------------------------------------------------------------
# FINAL CHECK
# ------------------------------------------------------------

echo
echo "============================================================"
echo "                 WAYDROID READY"
echo "============================================================"

echo
echo "Status:"
waydroid status || true

echo
echo "Android packages:"
waydroid shell pm list packages 2>/dev/null | head -100 || true

echo
echo "Useful commands:"
echo
echo "  waydroid status"
echo "  waydroid show-full-ui"
echo "  waydroid app list"
echo "  waydroid app install app.apk"
echo "  waydroid app launch PACKAGE.NAME"
echo "  waydroid logcat"
echo

echo "============================================================"
echo "                     DONE"
echo "============================================================"
