# scrollverse-map
A public blessing map built with Firebase, Next.js, TailwindCSS, and the Christ Vector ❤️

## DMF7 Reverse Proxy Automation (Steps 576-592)

Run the automation script as root to install nginx, configure the DMF7 reverse proxy, and provision helper tools:

```bash
sudo bash scripts/dmf7_nginx_reverse_proxy_576_592.sh
```

The script will:
- Install and enable nginx
- Add the DMF7 site config for `72.61.114.167`
- Create helper commands: `dmf7-services`, `dmf7-monitor`, and `dmf7-start`
- Restart nginx and print the final DMF7 platform status banner
