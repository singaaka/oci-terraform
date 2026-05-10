default:
    @just --list

# Encrypt secrets.tfvars into secrets.tfvars.age (interactive locally, AGE_PASSPHRASE env var in CI)
encrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age --passphrase -o secrets.tfvars.age secrets.tfvars
    else
        age --passphrase -o secrets.tfvars.age secrets.tfvars
    fi

# Decrypt secrets.tfvars.age into secrets.tfvars (interactive locally, AGE_PASSPHRASE env var in CI)
decrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age --decrypt -o secrets.tfvars secrets.tfvars.age
    else
        age --decrypt -o secrets.tfvars secrets.tfvars.age
    fi

# Initialise the OpenTofu backend (run decrypt first)
init:
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu init

# Show the execution plan (run decrypt first)
plan:
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu plan -var-file=secrets.tfvars

# Apply the configuration; extra flags are forwarded (e.g. just apply -auto-approve)
apply *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu apply -var-file=secrets.tfvars {{ ARGS }}
