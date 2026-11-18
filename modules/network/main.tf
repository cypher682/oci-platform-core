# ─────────────────────────────────────────────
# Network — VCN, gateways, subnets, NSGs, flow logs
# ─────────────────────────────────────────────
data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

resource "oci_core_vcn" "this" {
  compartment_id = var.compartment_id
  cidr_blocks    = [var.vcn_cidr]
  display_name   = "${var.project}-${var.environment}-vcn"
  dns_label      = "platform"

  freeform_tags = var.tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-igw"
  enabled        = true

  freeform_tags = var.tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nat"

  freeform_tags = var.tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-sgw"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }

  freeform_tags = var.tags
}

# ─────────────────────────────────────────────
# Route tables
# ─────────────────────────────────────────────
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-rt-public"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }

  freeform_tags = var.tags
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-rt-private"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }

  route_rules {
    destination       = data.oci_core_services.all_services.services[0].cidr_block
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.this.id
  }

  freeform_tags = var.tags
}

# ─────────────────────────────────────────────
# Security lists
# Security lists are the subnet-level boundary. NSGs below add
# workload-level rules. OCI is additive, so lists stay deliberately
# narrow and NSGs carry the least-privilege policy.
# ─────────────────────────────────────────────
resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-sl-public"

  ingress_security_rules {
    protocol    = "6"
    description = "HTTP from internet (OCI load balancers)"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol    = "6"
    description = "HTTPS from internet (OCI load balancers)"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    description = "OKE Kubernetes API endpoint"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    protocol    = "6"
    description = "SSH to the ops runner from the operator CIDR"
    source      = var.admin_cidr
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "All outbound traffic"
  }

  freeform_tags = var.tags
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-sl-private"

  ingress_security_rules {
    protocol    = "all"
    description = "All intra-VCN traffic"
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "All outbound traffic — NAT or service gateway"
  }

  freeform_tags = var.tags
}

resource "oci_core_security_list" "db" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-sl-db"

  ingress_security_rules {
    protocol    = "6"
    description = "Autonomous Database listener from app subnet"
    source      = var.app_subnet_cidr
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 1521
      max = 1521
    }
  }

  ingress_security_rules {
    protocol    = "6"
    description = "Autonomous Database listener from OKE nodes"
    source      = var.oke_node_subnet_cidr
    source_type = "CIDR_BLOCK"
    tcp_options {
      min = 1521
      max = 1521
    }
  }

  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    description      = "All outbound traffic"
  }

  freeform_tags = var.tags
}

# ─────────────────────────────────────────────
# Subnets
# ─────────────────────────────────────────────
resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.public_subnet_cidr
  display_name               = "${var.project}-${var.environment}-public"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false

  freeform_tags = merge(var.tags, { Tier = "public" })
}

resource "oci_core_subnet" "app" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.app_subnet_cidr
  display_name               = "${var.project}-${var.environment}-app"
  dns_label                  = "app"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = merge(var.tags, { Tier = "private" })
}

resource "oci_core_subnet" "db" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.db_subnet_cidr
  display_name               = "${var.project}-${var.environment}-db"
  dns_label                  = "db"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.db.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = merge(var.tags, { Tier = "database" })
}

resource "oci_core_subnet" "oke_nodes" {
  compartment_id             = var.compartment_id
  vcn_id                     = oci_core_vcn.this.id
  cidr_block                 = var.oke_node_subnet_cidr
  display_name               = "${var.project}-${var.environment}-oke-nodes"
  dns_label                  = "okenodes"
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  prohibit_public_ip_on_vnic = true

  freeform_tags = merge(var.tags, { Tier = "kubernetes" })
}

# ─────────────────────────────────────────────
# Network security groups
# ─────────────────────────────────────────────
resource "oci_core_network_security_group" "lb" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nsg-lb"
  freeform_tags  = var.tags
}

resource "oci_core_network_security_group" "app" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nsg-app"
  freeform_tags  = var.tags
}

resource "oci_core_network_security_group" "ops" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nsg-ops"
  freeform_tags  = var.tags
}

resource "oci_core_network_security_group" "db" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nsg-db"
  freeform_tags  = var.tags
}

resource "oci_core_network_security_group" "oke_api" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nsg-oke-api"
  freeform_tags  = var.tags
}

resource "oci_core_network_security_group" "oke_nodes" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.project}-${var.environment}-nsg-oke-nodes"
  freeform_tags  = var.tags
}

# LB: public HTTP/HTTPS in, app traffic out
resource "oci_core_network_security_group_security_rule" "lb_http_in" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "HTTP from internet"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_https_in" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "HTTPS from internet"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "lb_egress" {
  network_security_group_id = oci_core_network_security_group.lb.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Backend traffic"
  destination               = var.vcn_cidr
  destination_type          = "CIDR_BLOCK"
}

# App: accept only traffic from the LB and SSH from the ops runner
resource "oci_core_network_security_group_security_rule" "app_from_lb" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "HTTP from the OCI load balancer"
  source                    = oci_core_network_security_group.lb.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = 80
      max = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "app_ssh_from_ops" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "SSH from the ops runner only"
  source                    = oci_core_network_security_group.ops.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "app_ssh_from_bastion" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "SSH from the OCI Bastion endpoint in the app subnet"
  source                    = var.app_subnet_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "app_egress" {
  network_security_group_id = oci_core_network_security_group.app.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Egress to OCI services and database"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# Ops runner: operator SSH only, all egress
resource "oci_core_network_security_group_security_rule" "ops_ssh_in" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "SSH from operator CIDR"
  source                    = var.admin_cidr
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_network_security_group_security_rule" "ops_egress" {
  network_security_group_id = oci_core_network_security_group.ops.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "All egress"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# Database: SQL*Net from app and OKE nodes only
resource "oci_core_network_security_group_security_rule" "db_from_app" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "SQL*Net from app tier"
  source                    = oci_core_network_security_group.app.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = 1521
      max = 1521
    }
  }
}

resource "oci_core_network_security_group_security_rule" "db_from_oke" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "SQL*Net from OKE worker nodes"
  source                    = oci_core_network_security_group.oke_nodes.id
  source_type               = "NETWORK_SECURITY_GROUP"
  tcp_options {
    destination_port_range {
      min = 1521
      max = 1521
    }
  }
}

resource "oci_core_network_security_group_security_rule" "db_egress" {
  network_security_group_id = oci_core_network_security_group.db.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "All egress"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# OKE API endpoint: 6443 from anywhere (authenticated); tighten to admin_cidr in prod
resource "oci_core_network_security_group_security_rule" "oke_api_in" {
  network_security_group_id = oci_core_network_security_group.oke_api.id
  direction                 = "INGRESS"
  protocol                  = "6"
  description               = "Kubernetes API"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  tcp_options {
    destination_port_range {
      min = 6443
      max = 6443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "oke_api_egress" {
  network_security_group_id = oci_core_network_security_group.oke_api.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "All egress"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# OKE worker nodes: all intra-VCN traffic, all egress
resource "oci_core_network_security_group_security_rule" "oke_nodes_in" {
  network_security_group_id = oci_core_network_security_group.oke_nodes.id
  direction                 = "INGRESS"
  protocol                  = "all"
  description               = "Intra-VCN node, pod and control-plane traffic"
  source                    = var.vcn_cidr
  source_type               = "CIDR_BLOCK"
}

resource "oci_core_network_security_group_security_rule" "oke_nodes_egress" {
  network_security_group_id = oci_core_network_security_group.oke_nodes.id
  direction                 = "EGRESS"
  protocol                  = "all"
  description               = "Image pulls, OCI API, telemetry"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
}

# ─────────────────────────────────────────────
# VCN flow logs -> OCI Logging
# ─────────────────────────────────────────────
resource "oci_logging_log_group" "network" {
  compartment_id = var.compartment_id
  display_name   = "${var.project}-${var.environment}-network-logs"
  freeform_tags  = var.tags
}

resource "oci_logging_log" "vcn_flow" {
  display_name = "${var.project}-${var.environment}-vcn-flow"
  log_group_id = oci_logging_log_group.network.id
  log_type     = "SERVICE"
  is_enabled   = true

  configuration {
    source {
      category    = "vcn"
      resource    = oci_core_vcn.this.id
      service     = "flowlogs"
      source_type = "OCISERVICE"
    }
  }

  freeform_tags = var.tags
}
