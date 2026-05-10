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

provider "oci" {
  tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaam6g35gcgmifausay26wgxmzedkyhlctxcs6v4hhsgfppkm22v47a"
  user_ocid    = "ocid1.user.oc1..aaaaaaaaxerugeama3m3tunoh6q5eb62pn3i52lprhj2pepoan5m2b6ttcka"
  fingerprint  = "de:ba:6c:c5:8f:36:d6:e6:3d:8e:18:78:9c:12:37:ed"
  region       = "ap-mumbai-1"
  private_key  = var.private_key
}
