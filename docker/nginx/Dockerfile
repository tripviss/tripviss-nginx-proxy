FROM nginx:1.11-alpine

COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf

COPY docker/nginx/conf.d/gzip.conf /docker-entrypoint-conf.d/
COPY docker/nginx/conf.d/proxy_headers /docker-entrypoint-conf.d/

COPY docker/nginx/docker-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["nginx", "-g", "daemon off;"]
