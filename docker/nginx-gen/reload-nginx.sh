#!/bin/bash
set -e

docker_api() {
	local version='v1.25'
	local method=${2:-GET}
	local host
	local path="${1:-/}"
	local data="${3:-}"
	local curl_opts=(-s)
	if [ "$method" = 'POST' ]; then
		curl_opts+=(-d "$data")
		if [ -n "$data" ]; then
			curl_opts+=(-H 'Content-Type: application/json')
		fi
	elif [ -n "$data" ]; then
		curl_opts+=(--get)
		curl_opts+=(--data-urlencode "$data")
	fi
	if [ -z "$DOCKER_HOST" ]; then
		echo "Error DOCKER_HOST variable not set" >&2
		return 1
	fi
	if [ -n "${DOCKER_HOST#unix://}" ]; then
		curl_opts+=(--unix-socket "${DOCKER_HOST#unix://}")
		host='http://localhost'
	else
		host="http://${DOCKER_HOST#*://}"
	fi
	curl "${curl_opts[@]}" "${host}/${version}$path"
}

docker_kill() {
	local id="${1?missing id}"
	local signal="${2?missing signal}"
	docker_api "/containers/$id/kill?signal=$signal" "POST"
}

reload_nginx_container() {
	local id="${1?missing id}"
	echo "Reloading nginx (${id})..."
	docker_kill "${id}" SIGHUP
}

reload_nginx() {
	local filters
	local container_ids
	local container_id
	if [ "$MODE" = 'swarm' ]; then
		filters='{"label": ["com.github.jwilder.nginx_proxy.nginx"]}'
		container_ids=$(docker_api "/containers/json" "GET" "filters=$filters" | jq -r '[.[] | .Id] | join(" ")')
		for container_id in ${container_ids}; do
			reload_nginx_container "${container_id}"
		done
	elif [ -n "${NGINX_CONTAINER:-}" ]; then
		reload_nginx_container "${NGINX_CONTAINER}"
	fi
}

reload_nginx
