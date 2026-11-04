FROM nginx:1.30.6-alpine

COPY conf.default /etc/nginx/conf.d/default.conf
COPY html/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
