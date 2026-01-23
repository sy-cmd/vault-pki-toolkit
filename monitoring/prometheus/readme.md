## prometheus 
```
###Usage
# Start the exporter
./bin/vault-pki-exporter \
  --directory ./pki-output \
  --port 9100 \
  --verbose

# In another terminal, test the metrics endpoint
curl http://localhost:9100/metrics or where our prometheus is running 
```

# Test 2: Check Specific Metrics
```
# Check certificate expiry metrics
curl -s http://localhost:9100/metrics | grep cert_expiry_days

# Check status counts
curl -s http://localhost:9100/metrics | grep cert_status_total

# Check Vault health
curl -s http://localhost:9100/metrics | grep vault_pki_reachable
```

### Test with Prometheus 
```
# Start Prometheus with your config
prometheus --config.file=monitoring/prometheus/prometheus.yml

# Open Prometheus UI
# http://localhost:9090

# Query examples:
# cert_expiry_days_remaining
# cert_status_total
# rate(cert_renewal_success_total[5m])

```