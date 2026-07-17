# cloudflare.tf — DNS records for subdomains
#
# These CNAME records point your subdomains to the Cloudflare Tunnel.
# When someone visits grafana.karthikhegde.in, Cloudflare looks at
# this DNS record and routes the traffic through the tunnel to your VM.
#
# NOTE: These records are only created when tunnel_id is set.
# On your FIRST "terraform apply", leave tunnel_id empty.
# After creating the tunnel (Step 7), set tunnel_id and apply again.

# Only create DNS records if we have a tunnel ID
# count = 1 means "create this resource", count = 0 means "skip it"
# This is Terraform's way of doing an if-statement

resource "cloudflare_record" "grafana" {
  count   = var.tunnel_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  content = "${var.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  # proxied = true means traffic goes through Cloudflare's CDN
  # This gives you DDoS protection and hides your VM's real IP
}

resource "cloudflare_record" "status" {
  count   = var.tunnel_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "status"
  content = "${var.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "argocd" {
  count   = var.tunnel_id != "" ? 1 : 0
  zone_id = var.cloudflare_zone_id
  name    = "argocd"
  content = "${var.tunnel_id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}
