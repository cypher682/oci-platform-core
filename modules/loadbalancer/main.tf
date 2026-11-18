# ─────────────────────────────────────────────
# Load balancer — flexible shape, HTTP listener, health-checked backends
# ─────────────────────────────────────────────
resource "oci_load_balancer_load_balancer" "this" {
  compartment_id             = var.compartment_id
  display_name               = "${var.project}-${var.environment}-lb"
  shape                      = "flexible"
  subnet_ids                 = [var.subnet_id]
  is_private                 = false
  network_security_group_ids = [var.nsg_id]

  shape_details {
    minimum_bandwidth_in_mbps = var.min_bandwidth_mbps
    maximum_bandwidth_in_mbps = var.max_bandwidth_mbps
  }

  freeform_tags = var.tags
}

resource "oci_load_balancer_backend_set" "app" {
  load_balancer_id = oci_load_balancer_load_balancer.this.id
  name             = "app-backend-set"
  policy           = "ROUND_ROBIN"

  health_checker {
    protocol          = "HTTP"
    port              = var.backend_port
    url_path          = var.health_check_path
    interval_ms       = 10000
    timeout_in_millis = 3000
    retries           = 3
    return_code       = 200
  }

  session_persistence_configuration {
    cookie_name      = "oci_platform_session"
    disable_fallback = false
  }
}

resource "oci_load_balancer_backend" "app" {
  count = length(var.backend_ips)

  load_balancer_id = oci_load_balancer_load_balancer.this.id
  backendset_name  = oci_load_balancer_backend_set.app.name
  ip_address       = var.backend_ips[count.index]
  port             = var.backend_port
  weight           = 1
}

resource "oci_load_balancer_listener" "http" {
  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  name                     = "http"
  port                     = 80
  protocol                 = "HTTP"

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}

# ─────────────────────────────────────────────
# Optional HTTPS listener.
# Enable after creating a certificate in OCI Certificates service and
# passing its OCID as certificate_id.
# ─────────────────────────────────────────────
resource "oci_load_balancer_listener" "https" {
  count = var.certificate_id == null ? 0 : 1

  load_balancer_id         = oci_load_balancer_load_balancer.this.id
  default_backend_set_name = oci_load_balancer_backend_set.app.name
  name                     = "https"
  port                     = 443
  protocol                 = "HTTP"

  ssl_configuration {
    certificate_ids         = [var.certificate_id]
    verify_peer_certificate = false
  }

  connection_configuration {
    idle_timeout_in_seconds = 60
  }
}
