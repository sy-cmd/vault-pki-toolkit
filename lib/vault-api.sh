#!/bin/bash
#
# vault-api.sh
# Helper functions for Vault API interactions
#
# Author: Sydney Fwalanga
# Repository: https://github.com/sy-cmd/vault-pki-toolkit

# Vault API wrapper functions

vault_health_check() {
    # Check if Vault is accessible and unsealed
    local status
    if ! status=$(vault status 2>&1); then
        return 1
    fi
    
    if echo "$status" | grep -q "Sealed.*true"; then
        return 2
    fi
    
    return 0
}

vault_auth_check() {
    # Check if current token is valid
    vault token lookup &>/dev/null
    return $?
}

vault_read_secret() {
    # Read a secret from Vault
    # Usage: vault_read_secret <path> <field>
    local path="$1"
    local field="${2:-}"
    
    if [ -z "$field" ]; then
        vault read -format=json "$path"
    else
        vault read -field="$field" "$path"
    fi
}

vault_write_secret() {
    # Write a secret to Vault
    # Usage: vault_write_secret <path> <data>
    local path="$1"
    local data="$2"
    
    vault write -format=json "$path" @- <<< "$data"
}

vault_list_path() {
    # List items at a Vault path
    # Usage: vault_list_path <path>
    local path="$1"
    
    vault list -format=json "$path" 2>/dev/null || echo "[]"
}

vault_pki_issue() {
    # Issue a certificate from PKI backend
    # Usage: vault_pki_issue <pki_path> <role> <common_name> [ttl]
    local pki_path="$1"
    local role="$2"
    local common_name="$3"
    local ttl="${4:-720h}"
    
    vault write -format=json \
        "${pki_path}/issue/${role}" \
        common_name="$common_name" \
        ttl="$ttl"
}

vault_pki_revoke() {
    # Revoke a certificate
    # Usage: vault_pki_revoke <pki_path> <serial_number>
    local pki_path="$1"
    local serial_number="$2"
    
    vault write -format=json \
        "${pki_path}/revoke" \
        serial_number="$serial_number"
}

vault_pki_list_roles() {
    # List available PKI roles
    # Usage: vault_pki_list_roles <pki_path>
    local pki_path="$1"
    
    vault list -format=json "${pki_path}/roles" 2>/dev/null || echo "[]"
}

vault_pki_read_role() {
    # Read PKI role configuration
    # Usage: vault_pki_read_role <pki_path> <role>
    local pki_path="$1"
    local role="$2"
    
    vault read -format=json "${pki_path}/roles/${role}"
}

vault_get_ca_chain() {
    # Get CA certificate chain
    # Usage: vault_get_ca_chain <pki_path>
    local pki_path="$1"
    
    vault read -field=certificate "${pki_path}/cert/ca"
}

vault_get_crl() {
    # Get Certificate Revocation List
    # Usage: vault_get_crl <pki_path>
    local pki_path="$1"
    
    curl -s "${VAULT_ADDR}/v1/${pki_path}/crl"
}