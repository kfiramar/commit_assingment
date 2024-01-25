#!/bin/bash

# Path to aws-nuke (Update this to your aws-nuke location)
AWS_NUKE_PATH="./aws-nuke"

# Configuration file for aws-nuke
CONFIG_FILE="nuke-config1.yml"

# Create a basic configuration file
cat << EOF > $CONFIG_FILE
---
regions:
  - "global"
  - "eu-west-1"
  - "eu-west-1"

account-blocklist:
  - "000000000000" # Your actual account ID here for safety

resource-types:
  excludes:
    # don't nuke OpenSearch Packages, see https://github.com/rebuy-de/aws-nuke/issues/1123
    - OSPackage

accounts:
  "533267130709": {}
EOF

# Run aws-nuke with the configuration file
$AWS_NUKE_PATH -c $CONFIG_FILE --no-dry-run
