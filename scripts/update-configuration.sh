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
    local baseline="$PROJECT_ROOT/config/.example-state/$example"
    mkdir -p "$(dirname "$baseline")" || return 1
    cp "$PROJECT_ROOT/$example" "$baseline"
}

# Compare any example-backed file against the last accepted example. The
# optional renderer accounts for values managed separately by the installer.
tuoni_update_config_from_example() (
    local config="$1" example="$2" renderer="${3:-cat}"
    local active="$PROJECT_ROOT/$config" source="$PROJECT_ROOT/$example"
    local baseline="$PROJECT_ROOT/config/.example-state/$example"
    local work previous_version backup response have_previous=0
    work=$(mktemp -d) || return 1
    trap 'rm -rf -- "$work"' EXIT

    "$renderer" "$source" > "$work/new" || return 1
    if [[ ! -e "$active" ]]; then
        mkdir -p "$(dirname "$active")" || return 1
        cp "$work/new" "$active" || return 1
        tuoni_record_example "$example"
        return $?
    fi
    "$renderer" "$active" > "$work/active" || return 1
    if cmp -s "$work/active" "$work/new"; then
        tuoni_record_example "$example"
        return $?
    fi

    if [[ -f "$baseline" ]]; then
        cp "$baseline" "$work/previous" || return 1
        have_previous=1
    elif [[ -f "$PROJECT_ROOT/config/tuoni.env" ]]; then
        # Installations predating example snapshots can use their release tag.
        previous_version=$(sed -nE 's/^[[:space:]]*(export[[:space:]]+)?VERSION=[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*$/\2/p' "$PROJECT_ROOT/config/tuoni.env")
        if [[ -n "$previous_version" ]] && git -C "$PROJECT_ROOT" show "refs/tags/$previous_version:$example" > "$work/previous" 2>/dev/null; then
            have_previous=1
        fi
    fi

    if [[ "$have_previous" == 1 ]]; then
        # A customized active file needs no action if its example is unchanged.
        if cmp -s "$work/previous" "$source"; then
            tuoni_record_example "$example"
            return $?
        fi
        "$renderer" "$work/previous" > "$work/old" || return 1
    fi

    if [[ "$have_previous" != 1 ]] || ! cmp -s "$work/active" "$work/old"; then
        echo "WARNING | $example changed, or its previous version is unavailable." >&2
        echo "          $config does not match the previous example. Review your customizations before upgrading." >&2
        if [[ "${TUONI_FORCE_CONFIG:-}" == 1 ]]; then
            echo "WARNING | TUONI_FORCE_CONFIG=1: replacing $config with the new example after backing it up." >&2
        elif [[ "${SILENT:-}" == 1 ]]; then
            echo "ERROR | Silent upgrade stopped. Review interactively, or use --force-config / TUONI_FORCE_CONFIG=1 to back up and replace the file." >&2
            return 1
        else
            if ! read -r -p "Replace $config, keep your current file, or abort? [r/k/A] " response </dev/tty; then
                echo "ERROR | No interactive confirmation available; upgrade stopped." >&2
                return 1
            fi
            case "$response" in
                r|R|replace) ;;
                k|K|keep)
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
    cp "$work/new" "$active" || return 1
    tuoni_record_example "$example" || return 1
    echo "INFO | Updated $config from $example. Backup: $backup"
)

tuoni_update_configurations() {
    # Register example/active pairs here. YAML credentials and runtime .env
    # values continue to be managed by check-configuration.sh.
    local TUONI_CLIENT_PORT before="" after
    TUONI_CONFIG_UPDATED=0
    TUONI_CLIENT_PORT=$("$PROJECT_ROOT/scripts/tools/yq" '.client.port' "$PROJECT_ROOT/config/tuoni.yml") || return 1
    if [[ ! "$TUONI_CLIENT_PORT" =~ ^[0-9]+$ ]]; then
        echo "ERROR | Cannot update nginx configuration: client.port is invalid." >&2
        return 1
    fi
    if [[ -e "$PROJECT_ROOT/nginx/tuoni.conf" ]]; then
        before=$(sha256sum "$PROJECT_ROOT/nginx/tuoni.conf") || return 1
    fi
    tuoni_update_config_from_example nginx/tuoni.conf nginx/example/example.tuoni.conf tuoni_render_nginx_config || return 1
    after=$(sha256sum "$PROJECT_ROOT/nginx/tuoni.conf") || return 1
    if [[ "$before" != "$after" ]]; then
        TUONI_CONFIG_UPDATED=1
    fi
}
