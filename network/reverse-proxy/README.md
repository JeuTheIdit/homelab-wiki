# NGINX guides

## Table of contents
- [SSL/TLS hardening](#ssltls-hardening)
- [Headers](#headers)

## SSL/TLS hardening
This provides a drop‑in, safe SSL/TLS configuration for NGINX that works reliably with:
* Immich (web + mobile)
* Home Assistant (web + mobile)
* n8n
* Overseerr
* Notifiarr
* Plex (with caveats noted below)

It will likely work with most services, but is not tested.

The configuration is compatible with:
* Split‑horizon DNS
* Let’s Encrypt (DNS‑01)
* Internal + external access
* Mobile applications

It aligns with CIS Level 1 guidance, with optional level 2 enhancements noted. Further hardening can be done on a per-service basis.

### File

File location for NGINX: `/etc/nginx/snippets/ssl.conf`

File: [`ssl.conf`](ssl.conf)

## Plex specific notes (important)

Plex behaves differently from typical web applications. If Plex is reverse‑proxied, rathern than using its own plex.tv:

Disable HSTS for Plex by adding this after `ssl.conf`.

```nginx
add_header Strict-Transport-Security "" always;
```

Also set Plex secure connections to preferred:

```
Settings → Network → Secure connections = Preferred
```

---

### CIS Hardening Classification

#### Level 1 (baseline and implemented in this file)
* TLS 1.2 / 1.3 only
* Strong AEAD cipher suites
* Full certificate chain (fullchain.pem)
* Session resumption without tickets
* Safe security headers
* No legacy protocols or ciphers
* Compatible with mobile applications

#### Level 2 (optional and not implemented)
* OCSP stapling
* Rate limiting
* TLS 1.3‑only enforcement
* mTLS for admin routes
* HTTP/3 (Cloudflare)

### Verification Commands
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

## Headers
Below explains how to correctly use the default NGINX `proxy_params` file across services, and when additional proxy headers (such as WebSockets) are required.

It is intended for environments using:
* Reverse-proxied internal services
* Split-horizon DNS
* Let’s Encrypt (DNS-01)
* Hardened shared TLS configuration ([`ssl.conf`](ssl.conf))

### What `proxy_params` is for

On Debian/Ubuntu systems, the default `/etc/nginx/proxy_params` typically contains:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
```

These headers:
- Are safe to use globally
- Are expected by most modern applications
- Ensure correct URL generation, redirects, and logging
- Work correctly for both internal and external access

Best practice: Include `proxy_params` for all proxied services instead of repeating these headers per site.

### What `proxy_params` does not include

`proxy_params` intentionally does **not** include WebSocket-related headers:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

These headers:
- Are only needed for certain applications
- Can cause issues if applied blindly
- Should be enabled per service, not globally

### Recommended usage

```nginx
location / {
    proxy_pass http://backend.internal:PORT;

    include /etc/nginx/proxy_params;

    # Enable only if the service requires WebSockets
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    proxy_read_timeout 3600s;
}
```

This approach is:
- Clean
- Maintainable
- Secure
- Explicit

### Service-by-service requirements

| Service           | Include `proxy_params` | WebSocket Headers Required | Notes                                                 |
| ----------------- | ---------------------- | -------------------------- | ----------------------------------------------------- |
| Immich            | Yes                    | Yes                        | Required for uploads, background jobs, and mobile app |
| Home Assistant    | Yes                    | Yes                        | Required for live UI updates and mobile app           |
| n8n               | Yes                    | Yes                        | Required for UI and long-running workflows            |
| Overseerr         | Yes                    | Yes                        | Used for real-time UI updates                         |
| Notifiarr         | Yes                    | No                         | Webhook-based; no persistent connections              |
| Plex (if proxied) | Yes                    | Yes                        | WebSockets heavily used                               |

## Security considerations
- `X-Forwarded-*` headers are safe within trusted networks
- Do not expose internal backends directly to untrusted traffic without validation
- If using Cloudflare, handle real client IPs via `real_ip_header CF-Connecting-IP` at the HTTP level
- Avoid forwarding arbitrary headers from clients
