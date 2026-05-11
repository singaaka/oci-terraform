default:
    @just --list

# Encrypt secrets.tfvars into secrets.tfvars.age
encrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    age --recipient age1qq6tzchxqamul5sy5qfvrta8mmqu8t0w65zmmg47ryqqegfyh5hsldl83a -o secrets.tfvars.age secrets.tfvars

# Decrypt secrets.tfvars.age into secrets.tfvars (CI: AGE_IDENTITY env var; local: ~/.config/age/key.txt)
decrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${AGE_IDENTITY:-}" ]; then
        tmp=$(mktemp)
        trap "rm -f $tmp" EXIT
        printf '%s' "$AGE_IDENTITY" > "$tmp"
        age --decrypt --identity "$tmp" -o secrets.tfvars secrets.tfvars.age
    else
        age --decrypt --identity "${AGE_IDENTITY_FILE:-$HOME/.config/age/key.txt}" -o secrets.tfvars secrets.tfvars.age
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

# Destroy the configuration; extra flags are forwarded (e.g. just apply -auto-approve)
destroy *ARGS:
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu destroy -var-file=secrets.tfvars {{ ARGS }}
