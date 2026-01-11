# NGINX SSL/TLS Hardening Summary
This document provides a drop‑in, safe SSL/TLS configuration for NGINX that works reliably with:
* Immich (web + mobile)
* Home Assistant (web + mobile)
* n8n
* Overseerr
* Notifiarr
* Plex (with caveats noted below)

The configuration is compatible with:
* Split‑horizon DNS
* Let’s Encrypt (DNS‑01)
* Internal + external access
* Mobile applications

It aligns with CIS Level 1 guidance, with optional level 2 enhancements noted. Further hardening can be done on a per-service basis.

## Recommended SSL snippet (drop‑in)

File location for NGINX: `/etc/nginx/snippets/ssl.conf`

File: [`ssl.conf`](reverse-proxy/#ssl.conf)

## Standard server block template

Use this pattern for **each application** behind NGINX:

```nginx
server {
    listen 443 ssl http2;
    server_name app.example.com;

    ssl_certificate     /etc/nginx/ssl/app.fullchain.crt;
    ssl_certificate_key /etc/nginx/ssl/app.key;

    include /etc/nginx/snippets/ssl.conf;

    # Uploads and long-running requests
    client_max_body_size 0;
    send_timeout 3600s;

    location / {
        proxy_pass http://backend.internal:PORT;

        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSockets (required by Immich, Home Assistant, n8n, Overseerr)
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

## Plex specific notes (important)

Plex behaves differently from typical web applications. If Plex is reverse‑proxied, rathern than using its own plex.tv:

Disable HSTS for Plex:

```nginx
add_header Strict-Transport-Security "" always;
```

Plex setting:

```
Settings → Network → Secure connections = Preferred
```

---

## CIS Hardening Classification

### Level 1 (baseline and implemented)
* TLS 1.2 / 1.3 only
* Strong AEAD cipher suites
* Full certificate chain (fullchain.pem)
* Session resumption without tickets
* Safe security headers
* No legacy protocols or ciphers
* Compatible with mobile applications

### Level 2 (optional and not implemented)
* OCSP stapling
* Rate limiting
* TLS 1.3‑only enforcement
* mTLS for admin routes
* HTTP/3 (Cloudflare)

## Verification Commands

After deploying:

```bash
nginx -t && systemctl reload nginx
```

```bash
openssl s_client -connect app.example.com:443 -servername app.example.com
```

Expected output:

* `Verify return code: 0 (ok)`
* TLSv1.2 or TLSv1.3
* Valid certificate chain
