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

script_dir=$(dirname $(readlink -f $0))
cert_path=/etc/cert/$domain
acme_verify_path=/var/www/$domain
ngx_conf_file=/etc/nginx/sites-enabled/$domain

sudo python $script_dir/acme_tiny.py --account-key $cert_path/account.key --csr $cert_path/domain.csr --acme-dir $acme_verify_path 2> error.txt | sudo tee $cert_path/signed_chain.crt 

if [ -z "$(cat $cert_path/signed_chain.crt | grep CERTIFICATE)" ] || [ -z "$(cat error.txt | grep 'Certificate signed')" ]; then
    echo 'signing CA certificate failed'
    echo 'error message:'
    cat error.txt
    exit
fi

rm -f error.txt

sudo nginx -s reload

echo 'renew finished successfully'