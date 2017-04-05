[[ -z "${VHOST_DIR:-}" ]] && \
 declare -r VHOST_DIR=/etc/nginx/vhost.d
[[ -z "${START_HEADER:-}" ]] && \
 declare -r START_HEADER='## Start of configuration add by letsencrypt container'
[[ -z "${END_HEADER:-}" ]] && \
 declare -r END_HEADER='## End of configuration add by letsencrypt container'

add_location_configuration() {
	local domain="${1:-}"
	[[ -z "$domain" || ! -f "${VHOST_DIR}/${domain}" ]] && domain=default
	[[ -f "${VHOST_DIR}/${domain}" && \
	   -n $(sed -n "/$START_HEADER/,/$END_HEADER/p" "${VHOST_DIR}/${domain}") ]] && return 0
	echo "$START_HEADER" > "${VHOST_DIR}/${domain}".new
	cat /app/nginx_location.conf >> "${VHOST_DIR}/${domain}".new
	echo "$END_HEADER" >> "${VHOST_DIR}/${domain}".new
	[[ -f "${VHOST_DIR}/${domain}" ]] && cat "${VHOST_DIR}/${domain}" >> "${VHOST_DIR}/${domain}".new
	mv -f "${VHOST_DIR}/${domain}".new "${VHOST_DIR}/${domain}"
	return 1
}

remove_all_location_configurations() {
	local old_shopt_options=$(shopt -p) # Backup shopt options
	shopt -s nullglob
	for file in "${VHOST_DIR}"/*; do
		[[ -n $(sed -n "/$START_HEADER/,/$END_HEADER/p" "$file") ]] && \
		 sed -i "/$START_HEADER/,/$END_HEADER/d" "$file"
	done
	eval "$old_shopt_options" # Restore shopt options
}

## Docker API
docker_api() {
	local version='v1.25'
	local scheme
	local curl_opts=(-s)
	local method=${2:-GET}
	if [[ -n "${3:-}" ]]; then
		if [ "$method" = 'POST' ]; then
			curl_opts+=(-d "$3")
			curl_opts+=(-H 'Content-Type: application/json')
		else
			curl_opts+=(--data-urlencode "$3")
		fi
	fi
	if [[ -z "$DOCKER_HOST" ]];then
		echo "Error DOCKER_HOST variable not set" >&2
		return 1
	fi
	if [[ $DOCKER_HOST == unix://* ]]; then
		curl_opts+=(--unix-socket "${DOCKER_HOST#unix://}")
		scheme='http://localhost'
	else
		scheme="http://${DOCKER_HOST#*://}"
	fi
	curl "${curl_opts[@]}" -X"${method}" "${scheme}/${version}$1"
}

docker_exec() {
	local id="${1?missing id}"
	local cmd="${2?missing command}"
	local data=$(printf '{ "AttachStdin": false, "AttachStdout": true, "AttachStderr": true, "Tty":false,"Cmd": %s }' "$cmd")
	exec_id=$(docker_api "/containers/$id/exec" "POST" "$data" | jq -r .Id)
	if [[ -n "$exec_id" ]]; then
		docker_api /exec/$exec_id/start "POST" '{"Detach": false, "Tty":false}'
	fi
}

docker_kill() {
	local id="${1?missing id}"
	local signal="${2?missing signal}"
	docker_api "/containers/$id/kill?signal=$signal" "POST"
}

## Nginx
reload_nginx_container() {
	local id="${1?missing id}"
	local method=${2:-kill}
	echo "Reloading nginx proxy (${id})..."
	if [ "$method" != 'exec' ]; then
		docker_kill "${id}" SIGHUP
	else
		docker_exec "${id}" \
					'[ "sh", "-c", "/usr/local/bin/docker-gen -only-exposed /app/nginx.tmpl /etc/nginx/conf.d/default.conf; /usr/sbin/nginx -s reload" ]'
	fi
}

reload_nginx() {
	local filters
	local container_ids
	local container_id
	if [ "$MODE" = 'swarm' ]; then
		# Using separate nginx and docker-gen containers
		filters='{"label": ["com.github.jrcs.docker_letsencrypt_nginx_proxy_companion.docker_gen"]}'
		container_ids=$(docker_api "/containers/json" "GET" "filters=$filters" | jq -r '[.[] | .Id] | @sh')
		for container_id in ${container_ids}; do
			reload_nginx_container "${container_id}"
		done
		# Using combined nginx-proxy container
		filters='{"label": ["com.github.jrcs.docker_letsencrypt_nginx_proxy_companion.nginx_proxy"]}'
		container_ids=$(docker_api "/containers/json" "GET" "filters=$filters" | jq -r '[.[] | .Id] | @sh')
		for container_id in ${container_ids}; do
			reload_nginx_container "${container_id}" "exec"
		done
	elif [[ -n "${NGINX_DOCKER_GEN_CONTAINER:-}" ]]; then
		# Using separate nginx and docker-gen containers
		reload_nginx_container "${NGINX_DOCKER_GEN_CONTAINER}"
	elif [[ -n "${NGINX_PROXY_CONTAINER:-}" ]]; then
		# Using combined nginx-proxy container
		reload_nginx_container "${NGINX_PROXY_CONTAINER}" "exec"
	fi
}

# Convert argument to lowercase (bash 4 only)
lc() {
	echo "${@,,}"
}
