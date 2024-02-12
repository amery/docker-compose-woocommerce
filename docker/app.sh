#!/bin/sh

set -eu

cd /var/www

info() {
	echo
	echo "* $*"
}

query() {
	mysql -h$DB_SERVER ${DB_PORT:+-P$DB_PORT} "-u${DB_USER:-root}" ${DB_PASSWD:+-p"$DB_PASSWD"} "$@"
}

# wait for database
#
if [ -z "${DB_SERVER:-}" ]; then
	cat <<-EOT >&2
	error: DB_SERVER not specified
	EOT
	exit 1
fi

while true; do
	info "Checking if $DB_SERVER is available..."

	if query -e "status" > /dev/null 2>&1; then
		break
	fi

	info "Waiting for confirmation of MariaDB service startup"
	sleep 5
done
