#!/usr/bin/env bash
# ==============================================================================
# ProxPXE - Gerenciador de Autenticação e Sessões (100% Bash)
# ==============================================================================

set -eo pipefail

CONFIG_DIR="${CONFIG_DIR:-/data/config}"
AUTH_FILE="$CONFIG_DIR/auth.json"
SESSIONS_DIR="/tmp/proxpxe_sessions"

mkdir -p "$CONFIG_DIR" "$SESSIONS_DIR"

# Inicializa credenciais padrão (admin / admin) se não existirem
init_auth() {
    if [ ! -f "$AUTH_FILE" ]; then
        cat << 'EOF' > "$AUTH_FILE"
{
  "username": "admin",
  "password_hash": "admin"
}
EOF
        chmod 600 "$AUTH_FILE"
    fi
}

init_auth

# Valida login
validate_login() {
    local user="$1"
    local pass="$2"
    
    local stored_user
    local stored_pass
    stored_user=$(grep -o '"username": *"[^"]*"' "$AUTH_FILE" | cut -d'"' -f4 || echo "admin")
    stored_pass=$(grep -o '"password_hash": *"[^"]*"' "$AUTH_FILE" | cut -d'"' -f4 || echo "admin")

    if [ "$user" = "$stored_user" ] && [ "$pass" = "$stored_pass" ]; then
        # Gera token de sessão
        local token
        token=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N | md5sum | awk '{print $1}')
        echo "$user" > "$SESSIONS_DIR/$token"
        echo "$token"
        return 0
    else
        return 1
    fi
}

# Valida token de sessão
check_session() {
    local token="$1"
    [ -n "$token" ] && [ -f "$SESSIONS_DIR/$token" ]
}

# Altera senha
change_password() {
    local new_user="$1"
    local new_pass="$2"

    cat << EOF > "$AUTH_FILE"
{
  "username": "$new_user",
  "password_hash": "$new_pass"
}
EOF
    chmod 600 "$AUTH_FILE"
    echo "OK"
}

case "${1:-}" in
    login)
        validate_login "$2" "$3"
        ;;
    check)
        check_session "$2"
        ;;
    change)
        change_password "$2" "$3"
        ;;
esac
