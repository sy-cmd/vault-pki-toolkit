#!/bin/bash
#
# cert-utils.sh
# Certificate utility functions
#
# Author: Sydney Fwalanga
# Repository: https://github.com/sy-cmd/vault-pki-toolkit

# Certificate parsing and validation functions

cert_get_common_name() {
    # Extract common name from certificate
    # Usage: cert_get_common_name <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -subject | \
        sed -n 's/.*CN[[:space:]]*=[[:space:]]*\([^,]*\).*/\1/p'
}

cert_get_expiry_date() {
    # Get certificate expiry date
    # Usage: cert_get_expiry_date <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2
}

cert_get_expiry_epoch() {
    # Get certificate expiry as Unix epoch
    # Usage: cert_get_expiry_epoch <cert_file>
    local cert_file="$1"
    local expiry_date
    
    expiry_date=$(cert_get_expiry_date "$cert_file")
    
    # Try GNU date first, then BSD date
    date -d "$expiry_date" +%s 2>/dev/null || \
        date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_date" +%s 2>/dev/null
}

cert_get_days_until_expiry() {
    # Calculate days until certificate expires
    # Usage: cert_get_days_until_expiry <cert_file>
    local cert_file="$1"
    local expiry_epoch current_epoch
    
    expiry_epoch=$(cert_get_expiry_epoch "$cert_file")
    current_epoch=$(date +%s)
    
    echo $(( ($expiry_epoch - $current_epoch) / 86400 ))
}

cert_is_expired() {
    # Check if certificate is expired
    # Usage: cert_is_expired <cert_file>
    # Returns: 0 if expired, 1 if valid
    local cert_file="$1"
    local days_left
    
    days_left=$(cert_get_days_until_expiry "$cert_file")
    
    [ "$days_left" -lt 0 ]
}

cert_is_expiring_soon() {
    # Check if certificate expires within threshold
    # Usage: cert_is_expiring_soon <cert_file> <days_threshold>
    # Returns: 0 if expiring soon, 1 if not
    local cert_file="$1"
    local threshold="${2:-30}"
    local days_left
    
    days_left=$(cert_get_days_until_expiry "$cert_file")
    
    [ "$days_left" -lt "$threshold" ]
}

cert_get_serial() {
    # Get certificate serial number
    # Usage: cert_get_serial <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -serial | cut -d= -f2
}

cert_get_issuer() {
    # Get certificate issuer
    # Usage: cert_get_issuer <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -issuer | sed 's/issuer=//'
}

cert_get_subject() {
    # Get certificate subject
    # Usage: cert_get_subject <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//'
}

cert_get_san() {
    # Get Subject Alternative Names
    # Usage: cert_get_san <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -text | \
        grep -A1 "Subject Alternative Name" | \
        tail -n1 | \
        sed 's/^[[:space:]]*//'
}

cert_verify() {
    # Verify certificate is valid
    # Usage: cert_verify <cert_file> [ca_file]
    local cert_file="$1"
    local ca_file="${2:-}"
    
    if [ -n "$ca_file" ]; then
        openssl verify -CAfile "$ca_file" "$cert_file" &>/dev/null
    else
        openssl x509 -in "$cert_file" -noout &>/dev/null
    fi
}

cert_print_info() {
    # Print human-readable certificate information
    # Usage: cert_print_info <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -text
}

cert_to_pem() {
    # Convert certificate to PEM format
    # Usage: cert_to_pem <input_file> <output_file>
    local input_file="$1"
    local output_file="$2"
    
    openssl x509 -in "$input_file" -out "$output_file" -outform PEM
}

cert_fingerprint() {
    # Get certificate fingerprint
    # Usage: cert_fingerprint <cert_file> [algorithm]
    local cert_file="$1"
    local algorithm="${2:-sha256}"
    
    openssl x509 -in "$cert_file" -noout -fingerprint "-${algorithm}" | \
        cut -d= -f2
}

key_get_modulus() {
    # Get key modulus (for matching with certificate)
    # Usage: key_get_modulus <key_file>
    local key_file="$1"
    
    openssl rsa -in "$key_file" -noout -modulus 2>/dev/null
}

cert_get_modulus() {
    # Get certificate modulus (for matching with key)
    # Usage: cert_get_modulus <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -modulus
}

cert_key_match() {
    # Check if certificate and key match
    # Usage: cert_key_match <cert_file> <key_file>
    # Returns: 0 if match, 1 if no match
    local cert_file="$1"
    local key_file="$2"
    local cert_modulus key_modulus
    
    cert_modulus=$(cert_get_modulus "$cert_file")
    key_modulus=$(key_get_modulus "$key_file")
    
    [ "$cert_modulus" = "$key_modulus" ]
}

cert_get_key_size() {
    # Get certificate key size in bits
    # Usage: cert_get_key_size <cert_file>
    local cert_file="$1"
    
    openssl x509 -in "$cert_file" -noout -text | \
        grep "Public-Key:" | \
        sed 's/.*(\([0-9]*\) bit).*/\1/'
}

cert_format_expiry_status() {
    # Format expiry status with color coding
    # Usage: cert_format_expiry_status <days_left>
    local days_left="$1"
    local status color
    
    if [ "$days_left" -lt 0 ]; then
        status="EXPIRED"
        color="\033[0;31m" # Red
    elif [ "$days_left" -lt 7 ]; then
        status="CRITICAL"
        color="\033[0;31m" # Red
    elif [ "$days_left" -lt 30 ]; then
        status="WARNING"
        color="\033[0;33m" # Yellow
    else
        status="OK"
        color="\033[0;32m" # Green
    fi
    
    echo -e "${color}${status}\033[0m"
}