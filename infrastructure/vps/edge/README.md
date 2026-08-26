# Nginx for the erikspace.eu test deployment

This directory contains the complete Nginx configuration for the two test
domains. The final virtual hosts contain no placeholders and can be installed
unchanged on a standard Debian/Ubuntu Nginx installation whose
`/etc/nginx/conf.d/*.conf` files are included inside the `http` block.

## Files

- `campus-test-acme-bootstrap.conf` — temporary HTTP-only host used to obtain
  the first Let's Encrypt certificate;
- `campus-test-api.erikspace.eu.conf` — final public API host, including TLS,
  redirects, rate limits and a default-deny route policy;
- `campus-test-cms.erikspace.eu.conf` — final Strapi host, including TLS,
  redirects and the 30 MiB edge limit for the configured 25 MiB CMS upload
  limit.

Do not install the bootstrap and final files at the same time. They define the
same port-80 server names.

Remove an older installed `campus-api.conf` before enabling the final API file.
Keeping both would define the same rate-limit zones twice and make `nginx -t`
fail. The repository no longer contains that placeholder-based predecessor.

## Prerequisites

Before requesting the certificate:

1. `campus-test-api.erikspace.eu` and `campus-test-cms.erikspace.eu` must resolve
   directly to the VPS;
2. TCP ports 80 and 443 must be reachable;
3. ports 3020, 3021 and 5432 must remain private. Compose binds CMS and API to
   `127.0.0.1` already;
4. install Nginx and Certbot with the distribution packages;
5. create the persistent ACME webroot used by initial issuance and renewal.

```bash
sudo install -d -o root -g root -m 0755 /var/www/letsencrypt
```

The configuration assumes direct DNS. If another reverse proxy such as
Cloudflare is placed in front of Nginx, configure and verify trusted real-IP
handling before relying on the per-client rate limits.

## First certificate and installation

Copy all three files to a temporary directory on the VPS. Install only the
bootstrap first:

```bash
sudo install -o root -g root -m 0644 \
  campus-test-acme-bootstrap.conf \
  /etc/nginx/conf.d/campus-test-acme-bootstrap.conf
sudo nginx -t
sudo systemctl reload nginx
```

Obtain one certificate containing both test domains under the predictable
certificate name used by both final virtual hosts:

```bash
sudo certbot certonly \
  --webroot \
  --webroot-path /var/www/letsencrypt \
  --cert-name campus-koethen-test \
  -d campus-test-api.erikspace.eu \
  -d campus-test-cms.erikspace.eu
```

The certificate must now exist at:

```text
/etc/letsencrypt/live/campus-koethen-test/fullchain.pem
/etc/letsencrypt/live/campus-koethen-test/privkey.pem
```

Replace the bootstrap with the final virtual hosts:

```bash
sudo rm /etc/nginx/conf.d/campus-test-acme-bootstrap.conf
sudo install -o root -g root -m 0644 \
  campus-test-api.erikspace.eu.conf \
  /etc/nginx/conf.d/campus-test-api.erikspace.eu.conf
sudo install -o root -g root -m 0644 \
  campus-test-cms.erikspace.eu.conf \
  /etc/nginx/conf.d/campus-test-cms.erikspace.eu.conf
sudo nginx -t
sudo systemctl reload nginx
sudo certbot renew --dry-run
```

The port-80 blocks in the final files keep the ACME webroot reachable for
automatic renewal and redirect all other requests to HTTPS.

For later application deployments, copy the two final files only when their
contents changed. A normal container rollout does not require an Nginx reload
because ports and domains remain stable.

## API edge contract

The API is public and unauthenticated, so its final host applies these limits
before a request reaches Node:

| Promise                | Value                                             |
| ---------------------- | ------------------------------------------------- |
| Public paths           | `/v1/`, `/health/live`, `/health/ready`, `/docs*` |
| Every other path       | `404`                                             |
| General rate limit     | 10 requests/s per IP, burst 20                    |
| Media rate limit       | 2 requests/s per IP, burst 10                     |
| Documentation limit    | 5 requests/s per IP, burst 15                     |
| Concurrent connections | 20 per IP                                         |
| Request body           | maximum 1 KiB; the public API is read-only        |
| Allowed methods        | `GET`, `HEAD`, `OPTIONS`                          |
| Upstream               | `http://127.0.0.1:3021`                           |

`/docs` and `/docs-json` are intentionally public because the API is a public
read-only contract. `DOCS_ENABLED=true` in the deployment environment must
remain aligned with that edge decision.

## CMS edge contract

The CMS host forwards to `http://127.0.0.1:3020`. It deliberately adds no HTTP
Basic Auth: Strapi Admin provides its own login, and the Strapi content API has
no anonymous public role. The backend does not use the public CMS domain; it
connects over the internal Compose network with its server-side read-only
token.

Nginx accepts at most 30 MiB per request, leaving multipart overhead for the
CMS limit `UPLOAD_SIZE_LIMIT_BYTES=26214400` (25 MiB). Larger uploads are
rejected at the edge before they reach Strapi.

## Verification

After the containers and Nginx are running:

```bash
curl -I http://campus-test-api.erikspace.eu/health/ready
curl -I http://campus-test-cms.erikspace.eu/_health
curl -i https://campus-test-api.erikspace.eu/health/ready
curl -i https://campus-test-cms.erikspace.eu/_health
curl -i https://campus-test-api.erikspace.eu/
```

Expected results:

- both HTTP requests redirect to HTTPS;
- API readiness returns `200`;
- CMS health returns `204`;
- the API root returns `404` because it is not on the allowlist.

Finally, verify that the API rate limit is really active:

```bash
for i in $(seq 1 40); do
  curl -s -o /dev/null -w '%{http_code} ' \
    https://campus-test-api.erikspace.eu/v1/canteens
done
echo
```

The burst must eventually contain `429` responses. A sequence containing only
`200` responses means the edge limits are not active or the requests were too
slow to exceed them.
