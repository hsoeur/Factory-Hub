FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=5s --timeout=3s --start-period=3s --retries=5 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null || exit 1

