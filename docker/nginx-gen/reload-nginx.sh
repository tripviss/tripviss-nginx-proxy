#!/bin/bash
set -e

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
	elif [[ -n "${NGINX_CONTAINER:-}" ]]; then
		reload_nginx_container "${NGINX_CONTAINER}"
	fi
}

reload_nginx
