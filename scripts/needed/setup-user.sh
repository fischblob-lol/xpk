#!/bin/sh
# script to create xpk user which will handle all building and all executable shell commands

set -eu

buildusr="xpk"
tmpdir="/tmp/xpk"

if [ "$(id -u)" -ne 0 ]; then
    echo "[x] must be run as root (use sudo)" >&2
    exit 1
fi

osname="$(uname -s)"

userexist() {
    id -u "$buildusr" >/dev/null 2>&1
}

echo "[*] checking for existing '$buildusr' user..."

if userexist; then
    echo "[+] user '$buildusr' already exists, skipping creation"
else # creation shit
    case "$osname" in
        Linux)
            echo "[*] creating system user '$buildusr' (linux)..."
            useradd \
                --system \
                --no-create-home \
                --shell /bin/sh \
                "$buildusr"
            ;;
        Darwin) 
            echo "[*] creating system user '$buildusr' (darwin based systems)..." # also im pretty sure darwin is also for openbsd and such

            # find unused uid and take it
            newuid=""
            for candidate in $(seq 499 -1 200); do
                if ! dscl . -list /Users UniqueID | awk '{print $2}' | grep -qx "$candidate"; then
                    newuid="$candidate"
                    break
                fi
            done

            if [ -z "$newuid" ]; then
                echo "[x] no free system uid found in range 200-499, so i cannot do anythin" >&2
                exit 1
            fi

            dscl . -create "/Users/$buildusr"
            dscl . -create "/Users/$buildusr" UserShell /usr/bin/false
            dscl . -create "/Users/$buildusr" UniqueID "$newuid"
            dscl . -create "/Users/$buildusr" PrimaryGroupID 20
            dscl . -create "/Users/$buildusr" NFSHomeDirectory /var/empty

            echo "[+] created '$buildusr' with UID $newuid"
            ;;
        *)
            echo "[x] unsupported os: $osname" >&2
            exit 1
            ;;
    esac
fi
# ensures it is owned by user xpk, and xpk only
echo "[*] ensuring $tmpdir exists and is owned by '$buildusr'..."
mkdir -p "$tmpdir"
chown -R "$buildusr" "$tmpdir"
chmod 700 "$tmpdir"

echo "[+] setup complete: '$buildusr' owns $tmpdir"