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