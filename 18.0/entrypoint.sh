#!/bin/bash

set -e

# If PASSWORD_FILE is provided, read it
if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

# Set the postgres database host, port, user, and password according to the environment
# If the environment variable is not set, use default values
: ${HOST:=${DB_PORT_5432_TCP_ADDR:='postgres-container'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5433}}  # Change default port to 5433
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}

# Arguments to pass to the Odoo process
DB_ARGS=()

# Function to check if the config file has any database-related config and override it
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC" ; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" |cut -d " " -f3|sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}

# Call check_config for all necessary database parameters
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

# Main logic to start Odoo
case "$1" in
    -- | odoo)
        shift
        # If "scaffold", execute odoo scaffold command
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            # Wait for PostgreSQL to be ready
            wait-for-psql.py ${DB_ARGS[@]} --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"  # Start odoo with db args
        fi
        ;;
    -*)
        # Wait for PostgreSQL to be ready if the arguments contain any option with -
        wait-for-psql.py ${DB_ARGS[@]} --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"  # Start odoo with db args
        ;;
    *)
        # If not odoo command, just execute the provided command
        exec "$@"
esac

exit 1
