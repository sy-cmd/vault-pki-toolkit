## Ansible 

Structure 
```
ansible/
├── playbooks/
│   ├── deploy-toolkit.yml         # Main deployment playbook
│   ├── setup-vault-pki.yml        # Setup Vault PKI infrastructure
│   ├── request-certificates.yml   # Bulk certificate requests
│   └── update-toolkit.yml         # Update existing installations
├── templates/
│   ├── renewal-daemon.conf.j2
│   ├── vault-credentials.j2
│   ├── cert-renewal.service.j2
│   └── vault-pki-exporter.service.j2
├── inventory/
│   ├── production.ini
│   ├── localhost.ini
│   
└── README.md
```
### Prerequisites
On control machine:
```
# Install Ansible
sudo apt-get update
sudo apt-get install ansible

# Or via pip
pip3 install ansible

# Verify installation
ansible --version
```

Requirements:
+ Ansible 2.0+
+ SSH access to target hosts
+ Sudo privileges on target hosts
+ Vault server accessible from target hosts

Usage:
it needs sudo privileges 
```
# Setup PKI on Vault servers
ansible-playbook -i inventory/production.ini playbooks/setup-vault-pki.yml

# With custom domains
ansible-playbook -i inventory/production.ini playbooks/setup-vault-pki.yml \
  -e "pki_allowed_domains=mycompany.com,internal.mycompany.com"
```
```
# Test the playbook (dry run)
ansible-playbook -i ansible/inventory/localhost.ini \
  ansible/playbooks/deploy-toolkit.yml \
  --check \
  --diff
```

```
# Actually run it
ansible-playbook -i ansible/inventory/localhost.ini \
  ansible/playbooks/deploy-toolkit.yml \
  -e "vault_auth_token=$VAULT_TOKEN"
```