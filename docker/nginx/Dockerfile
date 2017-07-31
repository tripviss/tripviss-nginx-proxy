FROM nginx:1.13-alpine

COPY nginx.conf /etc/nginx/nginx.conf

COPY conf.d /docker-entrypoint-conf.d/

COPY docker-entrypoint /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint

ENTRYPOINT ["docker-entrypoint"]
CMD ["nginx", "-g", "daemon off;"]
