#!/bin/sh
# entrypoint-shim.sh — wraps upstream Seafile's /sbin/my_init supervisor.
#
# Responsibilities (in order):
#   1. Translate every *_FILE env var → plain env var (sourced from Docker
#      Swarm secrets mounted under /run/secrets/).
#   2. If /opt/seafile/conf/seahub_oauth_settings.py exists (mounted via the
#      seafile_seahub_oauth Docker config), wire it into seahub_settings.py
#      with a one-shot exec() append.
#   3. Hand off to upstream's supervisor (`exec /sbin/my_init -- "$@"`).
set -e

# --- 1) *_FILE -> plain env -----------------------------------------------
for var in $(env | awk -F= '/_FILE=/{print $1}'); do
    target=${var%_FILE}
    path=$(eval echo \"\$$var\")
    if [ -r "$path" ]; then
        value=$(cat "$path")
        export "$target=$value"
        unset "$var"
    fi
done

# --- 2) OIDC settings injection ------------------------------------------
SEAHUB_SETTINGS=/shared/seafile/conf/seahub_settings.py
OAUTH_CONFIG=/opt/seafile/conf/seahub_oauth_settings.py
if [ -f "$OAUTH_CONFIG" ]; then
    (
        while [ ! -f "$SEAHUB_SETTINGS" ]; do sleep 2; done
        if ! grep -q "seahub_oauth_settings" "$SEAHUB_SETTINGS"; then
            {
                echo ""
                echo "# OIDC settings (Docker config: seafile_seahub_oauth)"
                echo "exec(open('$OAUTH_CONFIG').read())"
            } >> "$SEAHUB_SETTINGS"
            # Nudge gunicorn so the new settings take effect on the worker fork
            sleep 8
            pkill -HUP -f gunicorn 2>/dev/null || true
        fi
    ) &
fi

# --- 3) Hand off to upstream supervisor ----------------------------------
exec /sbin/my_init -- "$@"
