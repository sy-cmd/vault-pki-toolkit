#!/bin/bash
#
# setup-vault-pki.sh
# Automated setup of HashiCorp Vault PKI infrastructure
#
# This script creates a two-tier PKI architecture:
# - Root CA (offline after initial setup)
# - Intermediate CA (online for certificate issuance)
#
# Author: Sydney Fwalanga
# Repository: https://github.com/sy-cmd/vault-pki-toolkit

set -euo pipefail

# ============================================================================
# Configuration
# ============================================================================

# Vault connection
VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

# PKI paths
ROOT_CA_PATH="${ROOT_CA_PATH:-pki}"
INT_CA_PATH="${INT_CA_PATH:-pki_int}"

# CA configuration
ROOT_CA_COMMON_NAME="${ROOT_CA_COMMON_NAME:-Internal Root CA}"
INT_CA_COMMON_NAME="${INT_CA_COMMON_NAME:-Internal Intermediate CA}"

# TTL configuration (in hours)
ROOT_CA_TTL="${ROOT_CA_TTL:-87600h}"      # 10 years
INT_CA_TTL="${INT_CA_TTL:-43800h}"        # 5 years
SERVER_CERT_TTL="${SERVER_CERT_TTL:-720h}" # 30 days
CLIENT_CERT_TTL="${CLIENT_CERT_TTL:-2160h}" # 90 days

# Domain configuration
ALLOWED_DOMAINS="${ALLOWED_DOMAINS:-example.com,internal.local}"

# Output directory for certificates
OUTPUT_DIR="${OUTPUT_DIR:-./pki-output}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

log_info() {
    echo -e "${BLUE}ℹ ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if vault CLI is installed
    if ! command -v vault &> /dev/null; then
        log_error "vault CLI not found. Please install HashiCorp Vault."
        log_info "Download from: https://www.vaultproject.io/downloads"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Please install jq for JSON processing."
        log_info "Install with: apt-get install jq  # or  brew install jq"
        exit 1
    fi
    
    # Check Vault connection
    if ! vault status &> /dev/null; then
        log_error "Cannot connect to Vault at $VAULT_ADDR"
        log_info "Make sure Vault is running and VAULT_ADDR is correct"
        exit 1
    fi
    
    # Check if Vault is sealed
    if vault status | grep -q "Sealed.*true"; then
        log_error "Vault is sealed. Please unseal it first."
        exit 1
    fi
    
    # Check if we have a valid token
    if ! vault token lookup &> /dev/null; then
        log_error "Invalid or missing Vault token"
        log_info "Set VAULT_TOKEN environment variable or login with: vault login"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

create_output_directory() {
    if [ ! -d "$OUTPUT_DIR" ]; then
        mkdir -p "$OUTPUT_DIR"
        log_success "Created output directory: $OUTPUT_DIR"
    fi
}

backup_existing_pki() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$OUTPUT_DIR/backup_$timestamp"
    
    # Check if PKI paths already exist
    if vault secrets list | grep -q "^${ROOT_CA_PATH}/"; then
        log_warn "Existing PKI found at $ROOT_CA_PATH"
        read -p "Do you want to backup and recreate? (yes/no): " -r
        echo
        if [[ $REPLY =~ ^[Yy]es$ ]]; then
            mkdir -p "$backup_dir"
            log_info "Backing up existing PKI to $backup_dir..."
            
            # Backup root CA certificate
            vault read -field=certificate "${ROOT_CA_PATH}/cert/ca" > "$backup_dir/root_ca.crt" 2>/dev/null || true
            
            # Disable existing mounts
            vault secrets disable "$ROOT_CA_PATH" 2>/dev/null || true
            vault secrets disable "$INT_CA_PATH" 2>/dev/null || true
            
            log_success "Backup completed"
        else
            log_error "Aborting setup"
            exit 0
        fi
    fi
}

setup_root_ca() {
    log_info "Setting up Root CA at $ROOT_CA_PATH..."
    
    # Enable PKI secrets engine for root CA
    vault secrets enable -path="$ROOT_CA_PATH" pki
    log_success "Enabled PKI secrets engine at $ROOT_CA_PATH"
    
    # Tune the mount to set max TTL
    vault secrets tune -max-lease-ttl="$ROOT_CA_TTL" "$ROOT_CA_PATH"
    log_success "Set max TTL to $ROOT_CA_TTL"
    
    # Generate root CA certificate
    log_info "Generating root CA certificate..."
    vault write -format=json \
        "${ROOT_CA_PATH}/root/generate/internal" \
        common_name="$ROOT_CA_COMMON_NAME" \
        ttl="$ROOT_CA_TTL" \
        key_bits=4096 \
        exclude_cn_from_sans=true \
        | tee "$OUTPUT_DIR/root_ca_response.json" \
        | jq -r '.data.certificate' > "$OUTPUT_DIR/root_ca.crt"
    
    log_success "Root CA certificate generated and saved to $OUTPUT_DIR/root_ca.crt"
    
    # Configure CA and CRL URLs
    vault write "${ROOT_CA_PATH}/config/urls" \
        issuing_certificates="$VAULT_ADDR/v1/${ROOT_CA_PATH}/ca" \
        crl_distribution_points="$VAULT_ADDR/v1/${ROOT_CA_PATH}/crl"
    
    log_success "Root CA setup complete"
}

setup_intermediate_ca() {
    log_info "Setting up Intermediate CA at $INT_CA_PATH..."
    
    # Enable PKI secrets engine for intermediate CA
    vault secrets enable -path="$INT_CA_PATH" pki
    log_success "Enabled PKI secrets engine at $INT_CA_PATH"
    
    # Tune the mount to set max TTL
    vault secrets tune -max-lease-ttl="$INT_CA_TTL" "$INT_CA_PATH"
    log_success "Set max TTL to $INT_CA_TTL"
    
    # Generate intermediate CA CSR
    log_info "Generating intermediate CA CSR..."
    vault write -format=json \
        "${INT_CA_PATH}/intermediate/generate/internal" \
        common_name="$INT_CA_COMMON_NAME" \
        key_bits=4096 \
        exclude_cn_from_sans=true \
        | tee "$OUTPUT_DIR/intermediate_csr_response.json" \
        | jq -r '.data.csr' > "$OUTPUT_DIR/pki_intermediate.csr"
    
    log_success "Intermediate CA CSR generated"
    
    # Sign intermediate certificate with root CA
    log_info "Signing intermediate certificate with root CA..."
    vault write -format=json \
        "${ROOT_CA_PATH}/root/sign-intermediate" \
        csr=@"$OUTPUT_DIR/pki_intermediate.csr" \
        format=pem_bundle \
        ttl="$INT_CA_TTL" \
        | tee "$OUTPUT_DIR/intermediate_signed_response.json" \
        | jq -r '.data.certificate' > "$OUTPUT_DIR/intermediate.cert.pem"
    
    log_success "Intermediate certificate signed"
    
    # Set the signed certificate
    vault write "${INT_CA_PATH}/intermediate/set-signed" \
        certificate=@"$OUTPUT_DIR/intermediate.cert.pem"
    
    log_success "Intermediate certificate installed"
    
    # Configure CA and CRL URLs
    vault write "${INT_CA_PATH}/config/urls" \
        issuing_certificates="$VAULT_ADDR/v1/${INT_CA_PATH}/ca" \
        crl_distribution_points="$VAULT_ADDR/v1/${INT_CA_PATH}/crl"
    
    log_success "Intermediate CA setup complete"
}

create_roles() {
    log_info "Creating certificate roles..."
    
    # Server certificate role
    vault write "${INT_CA_PATH}/roles/server" \
        allowed_domains="$ALLOWED_DOMAINS" \
        allow_subdomains=true \
        allow_bare_domains=false \
        allow_localhost=false \
        client_flag=false \
        server_flag=true \
        max_ttl="$SERVER_CERT_TTL" \
        ttl="$SERVER_CERT_TTL" \
        key_bits=2048 \
        key_usage="DigitalSignature,KeyEncipherment" \
        ext_key_usage="ServerAuth"
    
    log_success "Created 'server' role for server certificates"
    
    # Client certificate role
    vault write "${INT_CA_PATH}/roles/client" \
        allowed_domains="$ALLOWED_DOMAINS" \
        allow_subdomains=true \
        allow_bare_domains=false \
        allow_localhost=false \
        client_flag=true \
        server_flag=false \
        max_ttl="$CLIENT_CERT_TTL" \
        ttl="$CLIENT_CERT_TTL" \
        key_bits=2048 \
        key_usage="DigitalSignature" \
        ext_key_usage="ClientAuth"
    
    log_success "Created 'client' role for client certificates"
    
    # Wildcard role (for internal use)
    vault write "${INT_CA_PATH}/roles/wildcard" \
        allowed_domains="$ALLOWED_DOMAINS" \
        allow_subdomains=true \
        allow_bare_domains=true \
        allow_localhost=true \
        allow_wildcard_certificates=true \
        client_flag=true \
        server_flag=true \
        max_ttl="$SERVER_CERT_TTL" \
        ttl="$SERVER_CERT_TTL" \
        key_bits=2048
    
    log_success "Created 'wildcard' role for flexible certificates"
    
    log_success "All roles created successfully"
}

generate_test_certificate() {
    log_info "Generating test certificate to verify setup..."
    
    local test_domain
    # Extract first domain from ALLOWED_DOMAINS
    test_domain=$(echo "$ALLOWED_DOMAINS" | cut -d',' -f1)
    local test_cn="test.${test_domain}"
    
    vault write -format=json \
        "${INT_CA_PATH}/issue/server" \
        common_name="$test_cn" \
        ttl="24h" \
        | tee "$OUTPUT_DIR/test_certificate_response.json" \
        | jq -r '.data.certificate' > "$OUTPUT_DIR/test_certificate.crt"
    
    # Extract other components
    jq -r '.data.private_key' "$OUTPUT_DIR/test_certificate_response.json" > "$OUTPUT_DIR/test_certificate.key"
    jq -r '.data.ca_chain[]' "$OUTPUT_DIR/test_certificate_response.json" > "$OUTPUT_DIR/test_ca_chain.crt"
    
    # Verify the certificate
    if openssl x509 -in "$OUTPUT_DIR/test_certificate.crt" -noout -text > /dev/null 2>&1; then
        log_success "Test certificate generated and verified: $test_cn"
        
        # Show certificate details
        local expiry=$(openssl x509 -in "$OUTPUT_DIR/test_certificate.crt" -noout -enddate | cut -d= -f2)
        log_info "Test certificate expires: $expiry"
    else
        log_error "Test certificate verification failed"
    fi
}

print_summary() {
    echo ""
    echo "========================================================================"
    echo -e "${GREEN}Vault PKI Infrastructure Setup Complete!${NC}"
    echo "========================================================================"
    echo ""
    echo "Configuration Summary:"
    echo "  Vault Address:        $VAULT_ADDR"
    echo "  Root CA Path:         $ROOT_CA_PATH"
    echo "  Intermediate CA Path: $INT_CA_PATH"
    echo "  Output Directory:     $OUTPUT_DIR"
    echo ""
    echo "Created Roles:"
    echo "  - server   : Server certificates (TTL: $SERVER_CERT_TTL)"
    echo "  - client   : Client certificates (TTL: $CLIENT_CERT_TTL)"
    echo "  - wildcard : Flexible certificates with wildcard support"
    echo ""
    echo "Allowed Domains: $ALLOWED_DOMAINS"
    echo ""
    echo "Certificates saved to:"
    echo "  Root CA:              $OUTPUT_DIR/root_ca.crt"
    echo "  Intermediate CA:      $OUTPUT_DIR/intermediate.cert.pem"
    echo "  Test Certificate:     $OUTPUT_DIR/test_certificate.crt"
    echo ""
    echo "Next Steps:"
    echo "  1. Distribute root CA certificate to systems that need to trust it:"
    echo "     $OUTPUT_DIR/root_ca.crt"
    echo ""
    echo "  2. Request a certificate:"
    echo "     ./bin/request-cert -n myapp.example.com -r server"
    echo ""
    echo "  3. View available roles:"
    echo "     vault list ${INT_CA_PATH}/roles"
    echo ""
    echo "  4. Monitor certificates:"
    echo "     ./bin/monitor-certs"
    echo ""
    echo "========================================================================"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup HashiCorp Vault PKI infrastructure with root and intermediate CAs.

OPTIONS:
    -h, --help                Show this help message
    -a, --vault-addr ADDR     Vault address (default: $VAULT_ADDR)
    -r, --root-path PATH      Root CA path (default: $ROOT_CA_PATH)
    -i, --int-path PATH       Intermediate CA path (default: $INT_CA_PATH)
    -d, --domains DOMAINS     Allowed domains, comma-separated (default: $ALLOWED_DOMAINS)
    -o, --output DIR          Output directory (default: $OUTPUT_DIR)
    --root-ttl DURATION       Root CA TTL (default: $ROOT_CA_TTL)
    --int-ttl DURATION        Intermediate CA TTL (default: $INT_CA_TTL)
    --server-ttl DURATION     Server cert TTL (default: $SERVER_CERT_TTL)
    --client-ttl DURATION     Client cert TTL (default: $CLIENT_CERT_TTL)
    --skip-test              Skip test certificate generation

EXAMPLES:
    # Basic setup with defaults
    $0

    # Custom domains
    $0 --domains "mycompany.com,internal.mycompany.com"

    # Custom paths and TTLs
    $0 --root-path pki_root --int-path pki_intermediate --server-ttl 720h

ENVIRONMENT VARIABLES:
    VAULT_ADDR               Vault server address
    VAULT_TOKEN              Vault authentication token
    ROOT_CA_PATH             Root CA mount path
    INT_CA_PATH              Intermediate CA mount path
    ALLOWED_DOMAINS          Comma-separated list of allowed domains
    OUTPUT_DIR               Directory for certificate output

EOF
    exit 0
}

# ============================================================================
# Main Script
# ============================================================================

main() {
    # Parse command line arguments
    SKIP_TEST=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                ;;
            -a|--vault-addr)
                VAULT_ADDR="$2"
                shift 2
                ;;
            -r|--root-path)
                ROOT_CA_PATH="$2"
                shift 2
                ;;
            -i|--int-path)
                INT_CA_PATH="$2"
                shift 2
                ;;
            -d|--domains)
                ALLOWED_DOMAINS="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --root-ttl)
                ROOT_CA_TTL="$2"
                shift 2
                ;;
            --int-ttl)
                INT_CA_TTL="$2"
                shift 2
                ;;
            --server-ttl)
                SERVER_CERT_TTL="$2"
                shift 2
                ;;
            --client-ttl)
                CLIENT_CERT_TTL="$2"
                shift 2
                ;;
            --skip-test)
                SKIP_TEST=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                ;;
        esac
    done
    
    # Print banner
    echo ""
    echo "========================================================================"
    echo "  Vault PKI Infrastructure Setup"
    echo "========================================================================"
    echo ""
    
    # Run setup steps
    check_prerequisites
    create_output_directory
    backup_existing_pki
    setup_root_ca
    setup_intermediate_ca
    create_roles
    
    if [ "$SKIP_TEST" = false ]; then
        generate_test_certificate
    fi
    
    print_summary
    
    log_success "Setup completed successfully!"
}

# Run main function
main "$@"