FROM jwilder/docker-gen

RUN apk add --no-cache --virtual .persistent-deps \
		bash \
		curl \
		jq

COPY nginx-proxy/nginx.tmpl /etc/docker-gen/templates/nginx.tmpl

COPY docker/nginx-gen/reload-nginx.sh /usr/local/bin/

COPY docker/nginx-gen/docker-entrypoint /usr/local/bin/

ENTRYPOINT ["docker-entrypoint"]
