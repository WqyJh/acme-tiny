#!/bin/bash

# must run as sudo
if [[ $EUID > 0 ]]; then
    echo 'please run as sudo'
    exit
fi

if [ $# -lt 1 ]; then
    echo 'usage: sudo '$0' <domain>'
    exit
fi


domain=$1
keylen=2048

script_dir=$(dirname $(readlink -f $0))
cert_path=/etc/cert/$domain
acme_verify_path=/var/www/$domain
ngx_conf_file=/etc/nginx/sites-enabled/$domain
RAND_DIR=/tmp/$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

clean_and_exit() {
    cd $script_dir
    rm -r $RAND_DIR
    exit
}

echo 'making directories...'

if [ ! -d $RAND_DIR ]; then mkdir $RAND_DIR; fi
if [ ! -d $cert_path ]; then sudo mkdir $cert_path; fi
if [ ! -d $acme_verify_path ]; then sudo mkdir $acme_verify_path; fi

cd $RAND_DIR

echo 'generating ssl keys...'

openssl genrsa $keylen > account.key

openssl genrsa $keylen > domain.key

openssl req -new -sha256 -key domain.key -subj "/CN=$domain" > domain.csr


echo 'generating nginx config file...'

cat << EOF | sudo tee $ngx_conf_file
server {
	listen 80;
	server_name $domain;

	location /.well-known/acme-challenge/ {
	    alias $acme_verify_path/;
        try_files \$uri =404;
    }
}

EOF

echo 'testing nginx config file...'

ngx_out="$(sudo nginx -t 2>&1)"
if [[ $(echo "$ngx_out" | wc -l) > 2 || -z "$(echo $ngx_out | grep -o 'syntax is ok.*test is successful')" ]]; then
    echo "testing nginx config file failed, please checkout the file content manually: $ngx_conf_file"
    echo 'error message:'
    echo "$ngx_out"
    clean_and_exit
fi

sudo nginx -s reload

echo 'signing CA certificate...'

sudo python $script_dir/acme_tiny.py --account-key ./account.key --csr ./domain.csr --acme-dir /var/www/$domain > signed_chain.crt 2> error.txt

if [ -z "$(cat signed_chain.crt | grep CERTIFICATE)" ] || [ -z "$(cat error.txt | grep 'Certificate signed')" ]; then
    echo 'signing CA certificate failed'
    echo 'error message:'
    cat error.txt
    clean_and_exit
fi

rm -f error.txt

echo "copying ssl files to $cert_path..."

sudo cp account.key domain.key  domain.csr signed_chain.crt $cert_path

echo 'generating nginx config file...'

cat << EOF | sudo tee -a $ngx_conf_file
server {
	listen 80;
	server_name $domain;

	return 301 https://\$server_name\$request_uri;
}

server {
	listen 443 ssl;
	server_name $domain;

	ssl_certificate $cert_path/signed_chain.crt;
	ssl_certificate_key $cert_path/domain.key;
	ssl_session_timeout 5m;
	ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
	ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA;
	ssl_session_cache shared:SSL:50m;
	ssl_prefer_server_ciphers on;

    location /.well-known/acme-challenge/ {
	    alias $acme_verify_path/;
        try_files \$uri =404;
    }
}

EOF

echo 'testing nginx config file...'

ngx_out="$(sudo nginx -t 2>&1)"
if [[ $(echo "$ngx_out" | wc -l) > 2 || -z "$(echo $ngx_out | grep -o 'syntax is ok.*test is successful')" ]]; then
    echo "testing nginx config file failed, please checkout the file content manually: $ngx_conf_file"
    echo 'error message:'
    echo "$ngx_out"
    clean_and_exit
fi

sudo nginx -s reload

echo 'configure finished successfully!'

clean_and_exit
