# TAS (Trusted Artifact Signer) Monitoring  

Monitoring solution for Red Hat Trusted Artifact Signer (RHTAS) using Grafana and Prometheus.  

## Prerequisites  

Before deploying, ensure you have:  

1. **OpenShift Cluster Access**: You must be logged into an OpenShift cluster  
```bash  
oc whoami  
```  
2. **RHTAS Operator**: Red Hat Trusted Artifact Signer operator must be installed  
3. **Grafana Operator**: Grafana operator must be installed in the cluster  
4. **OIDC Configuration**: OIDC must be configured and ready  
5. **Securesign Deployment with Monitoring**: The following components must be deployed with monitoring enabled:  
- CTLog  
- Fulcio  
- Rekor  
- Trillian  
- TSA  


## Quick Start  

```bash  
git clone https://github.com/kdacosta0/tas-monitoring-stack.git  
cd tas-monitoring-stack  
make deploy  
```  
This will check prerequisites deploy grafana (default namespace `trusted-artifact-signer`) and output its URL.  
Default credentials: `admin / admin`  

**Deploy to custom namespace**:  

```bash  
make deploy NAMESPACE=my-tas-namespace  
```  

**Cleanup**:
```bash  
make clean  
```  

## Architecture  

This monitoring solution tracks the following KPIs:  

**Throughput Metrics**  
- `fulcio_new_certs` - Certificate issuance rate (fulcio-server)  
- `rekor_new_entries` - Transparency log entries (rekor-server)  
- `entries_added` - Log signer activity (trillian-logsigner)  
- `log_rpc_requests` - Log server requests (trillian-logserver)  
- `http_reqs` - Certificate transparency requests (ctlog)  
- `timestamp_authority_http_requests_total` - Timestamp requests (tsa-server)  

**Resource Metrics**  
- CPU Usage: `process_cpu_seconds_total`  
- Memory Usage: `go_memstats_heap_alloc_bytes`  