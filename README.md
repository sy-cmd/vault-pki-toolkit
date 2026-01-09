# vault-pki-toolkit
Vault PKI Toolkit automates certificate lifecycle management using HashiCorp Vault's PKI secrets engine. Born from production experience managing internal certificates at scale, this toolkit eliminates manual certificate operations and provides comprehensive monitoring.

## Problem 
Manual certificate management is:
+ Time-consuming (hours per certificate renewal)
+  Error-prone (missed expirations, wrong configurations)
+  Non-scalable (doesn't work for 10+ services)
+  Insecure (certificates living too long, manual key distribution)

##  The Solution
Vault PKI Toolkit provides:
+ Automated Vault PKI setup (root CA, intermediate CA, roles)
+ Simple certificate request CLI
+ Certificate expiration monitoring
+ Automatic renewal daemon
+ Prometheus metrics and Grafana dashboards
+ Ansible automation for deployment

## Structure
````
vault-pki-toolkit/
├── bin/                    # Executable scripts
├── lib/                    # Shared libraries
├── config/                 # Configuration templates
├── ansible/                # Ansible automation
├── monitoring/             # Prometheus & Grafana
├── systemd/                # Service files
├── docs/                   # Documentation
├── tests/                  # Test suite
└── examples/               # Integration examples
`````