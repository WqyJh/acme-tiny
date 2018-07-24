# acme-tiny

Forked from [diafygi/acme-tiny](https://github.com/diafygi/acme-tiny).

`acme-tiny` is a tiny script to issue and renew TLS certs from Let's Encrypt. It helps us to issue and renew [Let's Encrypt](https://letsencrypt.org/) within 6 steps while the official client requires you to fill many infomations by hand.

I prefer to use `acme-tiny` to issue my certs but I don't want to repeat the 6 steps every time. So I write this script `auto.sh` to help me quickly issue a cert for my site hosted on `nginx`.

## Usage

Assume you want to issue a new cert for `domain.com`.

1. Disable the pre-configured site with this domain.

    ```bash
    sudo unlink /etc/nginx/site-enabled/domain.com.conf
    sudo nginx -s reload
    ```

2. Issue a new cert by execute the script

    ```bash
    sudo ./auto.sh <domain>
    ```

    You'll see the output `configure finished successfully!` when it performs successfully.

    It will create two directories and one file.
    - `/etc/cert/domain.com` stores all the certificate files
    - `/var/www/domain.com` hosts the challenge files needed by Let's Encrypt to verify you site
    - `/etc/nginx/sites-enabled/domain.com` nginx config file with ssl support for your site

3. Config rules for your site
    
    ```bash
    sudo vim /etc/nginx/sites-enabled/domain.com

    server {
        listen 443 ssl;
        server_name domain.com;

        ssl_certificate /etc/cert/domain.com/signed_chain.crt;
        ssl_certificate_key /etc/cert/domain.com/domain.key;
        ssl_session_timeout 5m;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA;
        ssl_session_cache shared:SSL:50m;
        ssl_prefer_server_ciphers on;

        # ...
        # just copy from the original domain.com.conf to here

    }

    sudo nginx -s reload
    ```

## Renew

```bash
sudo ./renew.sh <domain>
```

use crontab to auto renew

```bash
sudo crontab -e

# Enter the following lines

# Example line in your crontab (runs once per month)
0 0 1 */2 * /path/to/renew.sh 2>> /var/log/renew.log
```

## Todo

- [ ] Support multiple domains
