terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.13.0"
    }
  }

  backend "s3" {
    bucket = "tofu-state"
    key    = "terraform.tfstate"
    region = "ap-mumbai-1"

    endpoint = "https://bm9h59pa3y0a.compat.objectstorage.ap-mumbai-1.oraclecloud.com"

    # Credentials are injected as env vars by the justfile (locally) or GitHub Actions (CI):
    #   AWS_ACCESS_KEY_ID     = var.access_key
    #   AWS_SECRET_ACCESS_KEY = var.secret_key

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    use_path_style              = true
  }
}

# All three secrets live in secrets.tfvars (gitignored) and secrets.tfvars.age (committed).
# Run `just decrypt` before tofu commands. Run `just encrypt` after editing secrets.tfvars.
# In GitHub Actions set AGE_PASSPHRASE as a secret; the workflow decrypts before tofu runs.

variable "private_key" { sensitive = true }
variable "access_key" { sensitive = true }
variable "secret_key" { sensitive = true }

locals {
  tenancy_ocid   = "ocid1.tenancy.oc1..aaaaaaaam6g35gcgmifausay26wgxmzedkyhlctxcs6v4hhsgfppkm22v47a"
  compartment_id = local.tenancy_ocid
}

provider "oci" {
  tenancy_ocid = local.tenancy_ocid
  user_ocid    = "ocid1.user.oc1..aaaaaaaaxerugeama3m3tunoh6q5eb62pn3i52lprhj2pepoan5m2b6ttcka"
  fingerprint  = "de:ba:6c:c5:8f:36:d6:e6:3d:8e:18:78:9c:12:37:ed"
  region       = "ap-mumbai-1"
  private_key  = var.private_key
}

# ── Network ──────────────────────────────────────────────────────────────────

resource "oci_core_vcn" "main" {
  compartment_id = local.compartment_id
  cidr_blocks    = ["10.0.0.0/16"]
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

resource "oci_core_default_security_list" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"
    udp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"
    udp_options {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.main.id
  cidr_block     = "10.0.0.0/24"
  route_table_id = oci_core_route_table.public.id
}

# ── Compute ───────────────────────────────────────────────────────────────────

data "oci_identity_availability_domains" "all" {
  compartment_id = local.compartment_id
}

data "oci_core_images" "ubuntu" {
  compartment_id           = local.compartment_id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "26.04"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
  state                    = "AVAILABLE"
}

resource "oci_core_instance" "main" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domains.all.availability_domains[0].name
  display_name        = "arm-01"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 200
    boot_volume_vpus_per_gb = 120
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "arm-01"
  }

  metadata = {
    ssh_authorized_keys = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICyfp8bUcH05Oz/lAfMkBybrOQHFVaQNeWD1A6jxLu8R singaaka@proton.me"
  }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "instance_public_ip" {
  value = oci_core_instance.main.public_ip
}

output "instance_id" {
  value = oci_core_instance.main.id
}

output "ssh_command" {
  value = "ssh ubuntu@${oci_core_instance.main.public_ip}"
}
