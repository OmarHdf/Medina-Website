
FROM nginx:alpine


RUN rm -rf /etc/nginx/conf.d/default.conf


COPY nginx-custom.conf /etc/nginx/conf.d/default.conf


COPY . /usr/share/nginx/html


EXPOSE 81

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --spider -q http://localhost:81 || exit 1
  
CMD ["nginx", "-g", "daemon off;"]
