# Pinned base image: never use "latest" so builds are reproducible.
FROM nginx:1.27-alpine

# Commit SHA injected by CI (docker build --build-arg BUILD_SHA=...).
ARG BUILD_SHA=dev

LABEL org.opencontainers.image.title="devops-intern-final" \
      org.opencontainers.image.source="https://github.com/tejas1121/devops-intern-final" \
      org.opencontainers.image.revision="${BUILD_SHA}"

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /usr/share/nginx/html/index.html

# Stamp the build SHA into the page and the X-Build-SHA header, then hand the
# directories NGINX needs over to the non-root "nginx" user (uid 101).
RUN sed -i "s/__BUILD_SHA__/${BUILD_SHA}/g" /usr/share/nginx/html/index.html /etc/nginx/nginx.conf \
    && chown -R nginx:nginx /usr/share/nginx/html /var/cache/nginx

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=2s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
