# Grafana Dashboard for Vault PKI Toolkit

Visual monitoring dashboard for certificate lifecycle management.

## 📊 Dashboard Overview

The Vault PKI Certificate Monitor dashboard provides:
- **Real-time certificate inventory** with status indicators
- **Expiration timeline** showing all certificates
- **Status summary** (healthy, warning, critical, expired)
- **Renewal activity tracking** (success/failure rates)
- **Vault PKI health monitoring**

## 🎨 Dashboard Features

### Top Row - Summary Statistics
- **Total Certificates**: Overall count of managed certificates
- **Healthy**: Certificates with 30+ days until expiration (green)
- **Warning**: Certificates with 7-30 days until expiration (yellow)
- **Critical**: Certificates with <7 days until expiration (red)
- **Expired**: Already expired certificates (dark red)
- **Vault PKI Status**: Vault connectivity indicator (UP/DOWN)

### Certificate Expiration Timeline
- Bar chart showing all certificates
- Color-coded by status (green → yellow → red)
- Sorted by days remaining
- Hover for detailed information

### Certificate Inventory Table
- Filterable and sortable table
- Shows: Common Name, File Path, Status, Days Remaining
- Color-coded status indicators with emojis
- Click column headers to sort

### Renewal Activity Chart
- Line graph showing renewal success/failure rates
- Green line: Successful renewals
- Red line: Failed renewals
- Aggregated by hour

## 🚀 Quick Setup

### Prerequisites
- Prometheus server running and scraping vault-pki-exporter
- Grafana 8.0+ installed
- vault-pki-exporter exposing metrics on port 9100

### Installation

#### Option 1: Import via Grafana UI

1. **Log into Grafana**
   ```
   http://your-grafana-server:3000
   ```

2. **Import Dashboard**
   - Click the "+" icon in left sidebar
   - Select "Import"
   - Click "Upload JSON file"
   - Select `vault-pki-dashboard.json`
   - Choose your Prometheus data source
   - Click "Import"
