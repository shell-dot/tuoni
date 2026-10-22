#!/bin/bash

# Render the installer-managed port in the first nginx server. Use the same
# rendering for comparisons and replacements so a configured port is preserved.
tuoni_render_nginx_config() {
    awk -v port="$TUONI_CLIENT_PORT" '
        /^server[[:space:]]*\{/ { servers++; in_server = (servers == 1) }
        {
            if (in_server && /^[[:space:]]*listen[[:space:]]+(\[::\]:)?[0-9]+([;[:space:]]|$)/) {
                sub(/listen[[:space:]]+(\[::\]:)?[0-9]+/,
                    "listen " ($0 ~ /^[[:space:]]*listen[[:space:]]+\[::\]:/ ? "[::]:" : "") port)
            }
            print
            if (/^}/) in_server = 0
        }
    ' "$1"
}

tuoni_record_example() {
    local example="$1"
    # Older snapshots could be recorded from an already-overwritten VERSION
    # without reviewing the active file. Revalidate them before trusting them.
    local baseline="$PROJECT_ROOT/config/.example-state/v2/$example"
    mkdir -p "$(dirname "$baseline")" || return 1
    cp "$PROJECT_ROOT/$example" "$baseline"
}

# Compare any example-backed file against the last accepted example. The
# optional renderer accounts for values managed separately by the installer.
# The change callback persists any service restart required by the new file.
tuoni_update_config_from_example() (
    local config="$1" example="$2" renderer="${3:-cat}" on_change="${4:-:}"
    local active="$PROJECT_ROOT/$config" source="$PROJECT_ROOT/$example"
    local baseline="$PROJECT_ROOT/config/.example-state/v2/$example"
    local work release backup response have_previous=0 matches_previous=0
    work=$(mktemp -d) || return 1
    trap 'rm -rf -- "$work"' EXIT

    "$renderer" "$source" > "$work/new" || return 1
    if [[ ! -e "$active" ]]; then
        mkdir -p "$(dirname "$active")" || return 1
        "$on_change" || return 1
        cp "$work/new" "$active" || return 1
        tuoni_record_example "$example"
        return $?
    fi
    "$renderer" "$active" > "$work/active" || return 1
    if cmp -s "$work/active" "$work/new"; then
        # A manual repair or an interrupted legacy upgrade may have changed the
        # file without restarting nginx. Apply newly accepted defaults as well.
        if ! cmp -s "$baseline" "$source"; then
            "$on_change" || return 1
        fi
        tuoni_record_example "$example"
        return $?
    fi

    # Recognize shipped defaults by their contents, even if VERSION or an older
    # snapshot incorrectly says they are current. Only use reachable releases.
    while IFS= read -r release; do
        [[ "$release" =~ ^refs/tags/[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
        if ! git -C "$PROJECT_ROOT" show "$release:$example" > "$work/candidate" 2>/dev/null; then
            continue
        fi
        "$renderer" "$work/candidate" > "$work/rendered-candidate" || return 1
        if cmp -s "$work/active" "$work/rendered-candidate"; then
            matches_previous=1
            break
        fi
    done < <(git -C "$PROJECT_ROOT" for-each-ref --merged=HEAD --sort=-version:refname --format='%(refname)' refs/tags)

    if [[ -f "$baseline" ]]; then
        cp "$baseline" "$work/previous" || return 1
        have_previous=1
    fi

    if [[ "$matches_previous" != 1 && "$have_previous" == 1 ]]; then
        # A customized active file needs no action if its example is unchanged.
        if cmp -s "$work/previous" "$source"; then
            tuoni_record_example "$example"
            return $?
        fi
        "$renderer" "$work/previous" > "$work/old" || return 1
        if cmp -s "$work/active" "$work/old"; then
            matches_previous=1
        fi
    fi

    if [[ "$matches_previous" != 1 ]]; then
        echo "WARNING | $example changed, or its previous version is unavailable." >&2
        echo "          $config does not match verified defaults. Review your customizations before continuing." >&2
        if [[ "${TUONI_FORCE_CONFIG:-}" == 1 ]]; then
            echo "WARNING | TUONI_FORCE_CONFIG=1: replacing $config with the new example after backing it up." >&2
        elif [[ "${SILENT:-}" == 1 ]]; then
            echo "ERROR | Configuration check stopped in silent mode. Review interactively, or set TUONI_FORCE_CONFIG=1 to back up and replace the file (--force-config for update commands)." >&2
            return 1
        else
            if ! read -r -p "Replace $config, keep after reviewing required changes, or abort? [r/k/A] " response </dev/tty; then
                echo "ERROR | No interactive confirmation available; upgrade stopped." >&2
                return 1
            fi
            case "$response" in
                r|R|replace) ;;
                k|K|keep)
                    "$on_change" || return 1
                    tuoni_record_example "$example" || return 1
                    echo "INFO | Keeping $config; recorded the new example as reviewed."
                    return 0
                    ;;
                *) echo "INFO | Upgrade stopped; $config was preserved." >&2; return 1 ;;
            esac
        fi
    fi

    backup=$(mktemp "$active.bak.XXXXXXXX") || return 1
    cp -p "$active" "$backup" || return 1
    "$on_change" || return 1
    cp "$work/new" "$active" || return 1
    tuoni_record_example "$example" || return 1
    echo "INFO | Updated $config from $example. Backup: $backup"
)

tuoni_require_nginx_restart() {
    mkdir -p "$PROJECT_ROOT/config/.example-state" || return 1
    touch "$PROJECT_ROOT/config/.example-state/nginx-restart-required"
}

tuoni_update_configurations() {
    # Register example/active pairs here. YAML credentials and runtime .env
    # values continue to be managed by check-configuration.sh.
    local TUONI_CLIENT_PORT
    # A running 0.17.0 updater can source this new helper after git pull while
    # still using its old restart condition. Preserve that handoff as well.
    TUONI_CONFIG_UPDATED=0
    TUONI_CLIENT_PORT=$("$PROJECT_ROOT/scripts/tools/yq" '.client.port' "$PROJECT_ROOT/config/tuoni.yml") || return 1
    if [[ ! "$TUONI_CLIENT_PORT" =~ ^[0-9]+$ ]]; then
        echo "ERROR | Cannot update nginx configuration: client.port is invalid." >&2
        return 1
    fi
    tuoni_update_config_from_example nginx/tuoni.conf nginx/example/example.tuoni.conf \
        tuoni_render_nginx_config tuoni_require_nginx_restart || return 1
    if [[ -f "$PROJECT_ROOT/config/.example-state/nginx-restart-required" ]]; then
        TUONI_CONFIG_UPDATED=1
    fi
}
