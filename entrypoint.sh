#!/bin/sh
web="ubuntu.com"
UUID="395bfff1-1b48-4dd7-9efd-ed3b1ff5553d"
apt update && apt install -y supervisor wget unzip iproute2
wget -O m.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
unzip m.zip && rm -f m.zip
chmod a+x xray
cat > config.yaml <<-EOF
log:
  loglevel: info
dns:
  servers:
  - https+local://8.8.8.8/dns-query
inbounds:
- port: 20000
  protocol: vless
  settings:
    decryption: none
    clients:
    - id: $UUID
  streamSettings:
    network: ws
    wsSettings:
      path: /$UUID-vless
  sniffing:
    enabled: false
    destOverride:
    - http
    - tls
    - quic
- port: 10000
  protocol: vmess
  settings:
    clients:
    - id: $UUID
  streamSettings:
    network: ws
    wsSettings:
      path: /$UUID-vmess
  sniffing:
    enabled: false
    destOverride:
    - http
    - tls
    - quic
- port: 40000
  protocol: shadowsocks
  settings:
    password: "$UUID"
    method: chacha20-ietf-poly1305
    ivcheck: true
  streamSettings:
    network: ws
    wsSettings:
      path: /$UUID-ss
  sniffing:
    enabled: false
    destOverride:
    - http
    - tls
    - quic
- port: 30000
  protocol: trojan
  settings:
    clients:
    - password: "$UUID"
  streamSettings:
    network: ws
    wsSettings:
      path: /$UUID-trojan
  sniffing:
    enabled: false
    destOverride:
    - http
    - tls
    - quic
outbounds:
- protocol: freedom
  tag: direct
  settings:
    domainStrategy: UseIPv4
EOF
cat > /etc/nginx/nginx.conf <<-EOF
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request"'
                    '\$status \$body_bytes_sent "\$http_referer"'
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    server {
        listen               80 default_server;
        listen               [::]:80 default_server;
        server_name          _;
        charset              utf-8;
        root                 html;

        location / {
            proxy_pass https://$web;
            proxy_redirect off;
            proxy_ssl_server_name on;
            sub_filter_once off;
            sub_filter "$web" \$server_name;
            proxy_set_header Host "$web";
            proxy_set_header Referer \$http_referer;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header User-Agent \$http_user_agent;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header Accept-Encoding "";
            proxy_set_header Accept-Language "zh-TW";
        }

        location /$UUID-vmess {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:10000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }

        location /$UUID-vless {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:20000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
        
        location /$UUID-trojan {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:30000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
        
        location /$UUID-ss {
            proxy_redirect off;
            proxy_pass http://127.0.0.1:40000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection upgrade;
            proxy_set_header Host \$http_host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
    }
}
EOF
xpid=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 6)
mv xray $xpid
cat config.yaml | base64 > config
rm -f config.yaml
nginx
base64 -d config > config.yaml; ./$xpid -config=config.yaml
