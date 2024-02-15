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

# msmtp logs
#
F=/var/log/msmtp.log
touch "$F"
chown appuser:appuser "$F"

# wp-cli
#
vendored="$PWD/vendor/wp-cli/wp-cli/bin/wp"
if [ ! -x "$vendored" ]; then
	F=composer.json
	if [ ! -s "$F" ]; then
		info "Generating $F..."
		cat <<-EOT > "$F~"
		{
		  "require": {
		  "wp-cli/wp-cli-bundle": "*"
		  }
		}
		EOT
		chown "appuser:appuser" "$F~"
	        mv "$F~" "$F"
	fi

        info "Running composer ..."
        run-user composer install --no-interaction
fi

WP=/usr/bin/wp
[ -x "$WP" ] || ln -s "$vendored" "$WP"

wp() {
	run-user "$WP" "$@"
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

# wp-config.php
#
F=wp-config.php
if [ ! -s "$F" ]; then
	info "DB server $DB_SERVER is available, configuring Workdpress"

	wp config create \
		--color \
		--dbname="$DB_NAME" \
		--dbuser="$DB_USER" \
		--dbpass="$DB_PASSWD" \
		--dbhost="$DB_SERVER" \
		${WP_LANG:+--locale=${WP_LANG}}

	run-user wp core install \
		--color \
		--url="https://$VIRTUAL_HOST" \
		--title="${WP_TITLE:-}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		${WP_LANG:+--locale=${WP_LANG}}

	run-user wp plugin install backup-backup
fi

info "Almost there! Starting web server now"
