terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 6.0.0"
    }
  }

  # Production should use remote state. See backend.tf.example and
  # docs/runbook.md before the first apply.
}

provider "oci" {
  region = var.region
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

data "oci_objectstorage_namespace" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  project     = var.project
  environment = var.environment

  availability_domain = var.availability_domain != null ? var.availability_domain : data.oci_identity_availability_domains.this.availability_domains[0].name

  common_tags = {
    Project     = local.project
    Environment = local.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = "portfolio-prod"
  }
}

module "iam" {
  source = "../../modules/iam"

  project               = local.project
  environment           = local.environment
  tenancy_ocid          = var.tenancy_ocid
  parent_compartment_id = var.compartment_ocid
  create_compartments   = var.create_compartments
  tags                  = local.common_tags
}

module "network" {
  source = "../../modules/network"

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id

  vcn_cidr             = "10.30.0.0/16"
  public_subnet_cidr   = "10.30.0.0/24"
  app_subnet_cidr      = "10.30.10.0/24"
  db_subnet_cidr       = "10.30.20.0/24"
  oke_node_subnet_cidr = "10.30.30.0/24"
  admin_cidr           = var.admin_cidr

  tags = local.common_tags
}

module "vault" {
  source = "../../modules/vault"

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id

  db_admin_password = var.db_admin_password
  tags              = local.common_tags
}

module "objectstorage" {
  source = "../../modules/objectstorage"

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id
  namespace      = data.oci_objectstorage_namespace.this.namespace
  kms_key_id     = module.vault.key_id

  tags = local.common_tags
}

module "compute_app" {
  source = "../../modules/compute"

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id

  availability_domain = local.availability_domain
  subnet_id           = module.network.app_subnet_id
  nsg_ids             = [module.network.nsg_app_id]

  shape                   = var.app_shape
  ocpus                   = var.app_ocpus
  memory_in_gbs           = var.app_memory_in_gbs
  boot_volume_size_in_gbs = 50
  instance_count          = var.app_instance_count
  instance_role           = "app"
  assign_public_ip        = false

  ssh_public_key = var.ssh_public_key
  tags           = local.common_tags
}

module "compute_ops" {
  source = "../../modules/compute"
  count  = var.enable_ops_runner ? 1 : 0

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id

  availability_domain = local.availability_domain
  subnet_id           = module.network.public_subnet_id
  nsg_ids             = [module.network.nsg_ops_id]

  shape                   = var.app_shape
  ocpus                   = 1
  memory_in_gbs           = 8
  boot_volume_size_in_gbs = 100
  instance_count          = 1
  instance_role           = "ops"
  assign_public_ip        = true

  ssh_public_key = var.ssh_public_key
  tags           = local.common_tags
}

module "loadbalancer" {
  source = "../../modules/loadbalancer"

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id

  subnet_id   = module.network.public_subnet_id
  nsg_id      = module.network.nsg_lb_id
  backend_ips = module.compute_app.private_ips

  certificate_id = var.lb_certificate_id
  tags           = local.common_tags
}

module "ocir" {
  source = "../../modules/ocir"

  compartment_id  = module.iam.compartment_id
  repository_name = "platform-api"
  region_key      = var.region_key
  namespace       = data.oci_objectstorage_namespace.this.namespace
  tags            = local.common_tags
}

module "oke" {
  source = "../../modules/oke"
  count  = var.enable_oke ? 1 : 0

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id
  region         = var.region

  vcn_id         = module.network.vcn_id
  api_subnet_id  = module.network.public_subnet_id
  lb_subnet_id   = module.network.public_subnet_id
  node_subnet_id = module.network.oke_node_subnet_id
  nsg_api_id     = module.network.nsg_oke_api_id
  nsg_nodes_id   = module.network.nsg_oke_nodes_id

  availability_domain = local.availability_domain
  kubernetes_version  = var.oke_kubernetes_version
  node_shape          = var.oke_node_shape
  node_ocpus          = var.oke_node_ocpus
  node_memory_in_gbs  = var.oke_node_memory_in_gbs
  node_count          = var.oke_node_count
  ssh_public_key      = var.ssh_public_key

  tags = local.common_tags
}

module "database" {
  source = "../../modules/database"
  count  = var.enable_adb ? 1 : 0

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id
  subnet_id      = module.network.db_subnet_id
  nsg_id         = module.network.nsg_db_id

  db_name                = var.adb_db_name
  admin_password         = var.db_admin_password
  private_endpoint_label = "${var.project}-${var.environment}-adb"
  tags                   = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  project        = local.project
  environment    = local.environment
  compartment_id = module.iam.compartment_id

  alert_email      = var.alert_email
  enable_adb_alarm = var.enable_adb
  tags             = local.common_tags
}

module "bastion" {
  source = "../../modules/bastion"
  count  = var.enable_bastion ? 1 : 0

  project          = local.project
  environment      = local.environment
  compartment_id   = module.iam.compartment_id
  target_subnet_id = module.network.app_subnet_id
  allowed_cidrs    = [var.admin_cidr]

  tags = local.common_tags
}

module "budget" {
  source = "../../modules/budget"
  count  = var.enable_budget ? 1 : 0

  project               = local.project
  environment           = local.environment
  tenancy_ocid          = var.tenancy_ocid
  target_compartment_id = module.iam.compartment_id
  amount                = var.budget_amount
  alert_email           = var.alert_email
  tags                  = local.common_tags
}
