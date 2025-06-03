#!/usr/bin/env bash

# Script to set up agenix for Mullvad VPN secrets

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}--- Agenix Mullvad Setup ---${NC}\n"

if [ ! -f "flake.nix" ]; then
    echo -e "${RED}Error: Run this script from your flake directory${NC}"
    exit 1
fi

echo "1. Checking SSH keys..."
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "   Creating user SSH key..."
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
fi

USER_KEY=$(cat ~/.ssh/id_ed25519.pub)
HOST_KEY=$(sudo cat /etc/ssh/ssh_host_ed25519_key.pub)

echo -e "   ${GREEN}✓${NC} User key: ${USER_KEY:0:50}..."
echo -e "   ${GREEN}✓${NC} Host key: ${HOST_KEY:0:50}...\n"

echo "2. Creating secrets.nix..."
cat > secrets.nix << EOF
let
  workstation = "$HOST_KEY";
  elos = "$USER_KEY";

  allKeys = [ workstation elos ];
in
{
  "secrets/mullvad-host-account.age".publicKeys = allKeys;
  "secrets/mullvad-guest-account.age".publicKeys = allKeys;
}
EOF
echo -e "   ${GREEN}✓${NC} Created secrets.nix\n"

echo "3. Creating secrets directory..."
mkdir -p secrets
echo -e "   ${GREEN}✓${NC} Created secrets/\n"

echo "4. Setting up Mullvad accounts..."
echo -e "   ${YELLOW}Note: Get your Mullvad account numbers from https://mullvad.net${NC}"
echo

read -p "   Enter your HOST Mullvad account number: " HOST_ACCOUNT
read -p "   Enter your GUEST Mullvad account number: " GUEST_ACCOUNT

if [ -z "$HOST_ACCOUNT" ] || [ -z "$GUEST_ACCOUNT" ]; then
    echo -e "\n${RED}Error: Both account numbers are required${NC}"
    exit 1
fi

if ! command -v ragenix &> /dev/null; then
    echo -e "\n5. Installing agenix..."
    nix-shell -p ragenix --run "echo 'Agenix available'"
fi

echo -e "\n6. Encrypting Mullvad accounts..."

TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'SCRIPT'
#!/usr/bin/env bash
cat > "$1"
SCRIPT
chmod +x "$TEMP_SCRIPT"

echo -n "$HOST_ACCOUNT" | EDITOR="$TEMP_SCRIPT" nix-shell -p ragenix --run "cd $(pwd) && ragenix -e secrets/mullvad-host-account.age"

echo -n "$GUEST_ACCOUNT" | EDITOR="$TEMP_SCRIPT" nix-shell -p ragenix --run "cd $(pwd) && ragenix -e secrets/mullvad-guest-account.age"

rm -f "$TEMP_SCRIPT"

echo -e "   ${GREEN}✓${NC} Encrypted Mullvad accounts\n"
