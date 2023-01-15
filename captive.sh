#!/bin/bash
set -e

#make any required changes
IFACE='wlan0'
SSID='wifi'
DOMAIN='anyrandom.domain'
PASSWORD=''
CAPTIVE_PORT='30123'
CONTAINER_NAME='captive_site'
IMAGE_NAME='captive_portal'
IPNUM='66'

[[ -z "$PASSWORD" ]] || PASSWORD="-p $PASSWORD"

tee nginx.conf <<EOF > /dev/null
worker_processes auto;
error_log stderr warn;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include mime.types;
    default_type application/octet-stream;

    # Define custom log format to include reponse times
    log_format main_timed '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                          '\$status \$body_bytes_sent "\$http_referer" '
                          '"\$http_user_agent" "\$http_x_forwarded_for" '
                          '\$request_time \$upstream_response_time \$pipe \$upstream_cache_status';

    access_log /dev/stdout main_timed;
    error_log /dev/stderr notice;

    keepalive_timeout 65;

    # Write temporary files to /tmp so they can be created as a non-privileged user
    client_body_temp_path /tmp/client_temp;
    proxy_temp_path /tmp/proxy_temp_path;
    fastcgi_temp_path /tmp/fastcgi_temp;
    uwsgi_temp_path /tmp/uwsgi_temp;
    scgi_temp_path /tmp/scgi_temp;

    #inject location header
		server {
        listen [::]:$CAPTIVE_PORT default_server;
        listen $CAPTIVE_PORT default_server;

        return 301 http://$DOMAIN;
		}

    server {
        listen [::]:$CAPTIVE_PORT;
        listen $CAPTIVE_PORT;
        server_name $DOMAIN;

        sendfile off;
        tcp_nodelay on;
        absolute_redirect off;

        root /var/www/html;
        index index.php index.html;

        location / {
            # First attempt to serve request as file, then
            # as directory, then fall back to index.php
            try_files \$uri \$uri/ /index.php?q=\$uri&\$args;
        }

        # Redirect server error pages to the static page /50x.html
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /var/lib/nginx/html;
        }

        # Pass the PHP scripts to PHP-FPM listening on php-fpm.sock
        location ~ \\.php$ {
            try_files \$uri =404;
            fastcgi_split_path_info ^(.+\\.php)(/.+)$;
            fastcgi_pass unix:/run/php-fpm.sock;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            fastcgi_param SCRIPT_NAME \$fastcgi_script_name;
            fastcgi_index index.php;
            include fastcgi_params;
        }

        location ~* \\.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
            expires 5d;
        }

        # Deny access to . files, for security
        location ~ /\\. {
            log_not_found off;
            deny all;
        }

        # Allow fpm ping and status from localhost
        location ~ ^/(fpm-status|fpm-ping)$ {
            access_log off;
            allow 127.0.0.1;
            deny all;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
            include fastcgi_params;
            fastcgi_pass unix:/run/php-fpm.sock;
        }
    }
    
    # Hardening
    proxy_hide_header X-Powered-By;
    fastcgi_hide_header X-Powered-By;
    server_tokens off;
    
    gzip on;
    gzip_proxied any;
    gzip_types text/plain application/xml text/css text/js text/xml application/x-javascript text/javascript application/json application/xml+rss;
    gzip_vary on;
    gzip_disable "msie6";
    
    # Include other server configs
    include /etc/nginx/conf.d/*.conf;
}
EOF

#setup web server for captive portal
docker build -t "$IMAGE_NAME" .
docker run --name "$CONTAINER_NAME" -it --rm -d --network host -v "$(pwd)/site:/var/www/html" "$IMAGE_NAME"

#make rule to redirect all http requests to captive portal page
iptables -i lnxr0 -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination "192.168.$IPNUM.1:$CAPTIVE_PORT"

#start the AP
./linux-router/lnxrouter --ap "$IFACE" "$SSID" $PASSWORD -g "$IPNUM" --hostname "$DOMAIN" --random-mac --virt-name lnxr0 -e "$(pwd)/domains.txt"

#remove rule
iptables -i lnxr0 -t nat -D PREROUTING -p tcp --dport 80 -j DNAT --to-destination "192.168.$IPNUM.1:$CAPTIVE_PORT"

#stop container
docker stop "$CONTAINER_NAME"
