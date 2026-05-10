# Encrypt secrets.tfvars -> secrets.tfvars.age
# Locally: prompts for passphrase interactively
# In CI: reads passphrase from AGE_PASSPHRASE env var
encrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age --passphrase -o secrets.tfvars.age secrets.tfvars
    else
        age --passphrase -o secrets.tfvars.age secrets.tfvars
    fi

# Decrypt secrets.tfvars.age -> secrets.tfvars
# Locally: prompts for passphrase interactively
# In CI: reads passphrase from AGE_PASSPHRASE env var
decrypt:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${AGE_PASSPHRASE:-}" ]; then
        printf '%s' "$AGE_PASSPHRASE" | age --decrypt -o secrets.tfvars secrets.tfvars.age
    else
        age --decrypt -o secrets.tfvars secrets.tfvars.age
    fi

# Inject S3 backend credentials from secrets.tfvars as env vars, then run tofu init
init: decrypt
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu init

# Inject S3 backend credentials from secrets.tfvars as env vars, then run tofu plan
plan: decrypt
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu plan -var-file=secrets.tfvars

# Inject S3 backend credentials from secrets.tfvars as env vars, then run tofu apply
apply: decrypt
    #!/usr/bin/env bash
    set -euo pipefail
    export AWS_ACCESS_KEY_ID=$(grep '^access_key' secrets.tfvars | awk -F'"' '{print $2}')
    export AWS_SECRET_ACCESS_KEY=$(grep '^secret_key' secrets.tfvars | awk -F'"' '{print $2}')
    tofu apply -var-file=secrets.tfvars
