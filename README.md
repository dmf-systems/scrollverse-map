# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 SSL automation (steps 593-610)
Run the helper script to install Certbot, request an nginx certificate, and provision the DMF7 maintenance tools:

```bash
sudo DMF7_DOMAIN=example.com DMF7_CERTBOT_EMAIL=admin@example.com bash scripts/dmf7_ssl_operations_593_610.sh
```

The script installs Certbot, obtains the certificate for the provided domain, creates the `dmf7-ssl`, `dmf7-update`, `dmf7-metrics`, and `dmf7-info` commands in `/usr/local/bin`, and prints the final DMF7 platform status banner.
