FROM alpine:3.10
LABEL maintainer="flsixtyfour@gmail.com"
ENV UID=1001
WORKDIR /app
RUN apk --update upgrade && \
    apk add --update --no-cache nginx && \
    rm -rf /var/cache/apk/* && \
    ln -sf /dev/stdout /var/log/nginx/access.log && ln -sf /dev/stderr /var/log/nginx/error.log && \
    chown ${UID} -Rv /var/tmp/nginx /var/log/nginx /var/lib/nginx /app
COPY nginx.conf /etc/nginx/nginx.conf
EXPOSE 8000
USER ${UID}
ENTRYPOINT ["nginx","-g", "daemon off;"]
