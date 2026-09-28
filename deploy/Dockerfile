# syntax=docker/dockerfile:1.7

FROM nginx:1.27-alpine

# Remove the default config so only ours is active.
RUN rm -f /etc/nginx/conf.d/default.conf

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/conf.d/ /etc/nginx/conf.d/
COPY nginx/snippets/ /etc/nginx/snippets/
COPY nginx/routes/ /etc/nginx/routes/

RUN nginx -t

EXPOSE 80