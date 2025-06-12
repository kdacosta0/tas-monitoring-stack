# TAS (Trusted Artifact Signer) Monitoring

Enterprise-grade monitoring solution for Red Hat Trusted Artifact Signer (RHTAS) using Grafana and Prometheus with corrected performance metrics and security hardening.

## Prerequisites

Before deploying, ensure you have:

1. **OpenShift Cluster Access**: You must be logged into an OpenShift cluster
```bash
oc whoami
```

2. **RHTAS Operator**: Red Hat Trusted Artifact Signer operator must be installed
```bash
oc get csv -A | grep rhtas-operator
```


3. **Grafana Operator**: Grafana operator must be installed in the cluster
```bash
oc get csv -n openshift-operators | grep grafana-operator
```

4. **OIDC Configuration**: OIDC must be configured and ready for your TAS deployment

5. **Securesign Deployment with Monitoring**: All TAS components must be deployed with monitoring enabled:
    - **fulcio** (Certificate Authority)
    - **rekor** (Transparency Log)  
    - **trillian** (Backend Database)
    - **ctlog** (Certificate Transparency)
    - **tsa** (Timestamp Authority)

## Quick Start
```bash
git clone https://github.com/kdacosta0/tas-monitoring-stack.git
cd tas-monitoring-stack
make deploy
```
This will:
- Check all prerequisites
- Deploy Grafana to `trusted-artifact-signer` namespace
- Configure secure Prometheus datasource (30-day token)
- Deploy corrected performance dashboard
- Output Grafana URL

**Default credentials**: `admin / admin` ⚠️

## Cleanup
```bash
make clean
```

## Architecture

### **Dashboard Panels**
1. **Primary Business Throughput** - Core signing operations (certificates, entries, processing)
2. **API & System Throughput** - All HTTP/gRPC requests and system operations  
3. **CPU Usage by Component** - Per-component CPU utilization with proper calculation
4. **Memory Usage by Component** - Actual memory consumption in MB
5. **Overall Resource Gauges** - Total CPU and memory with realistic thresholds
6. **Performance Summary** - Key metrics for last 10 minutes
7. **Component Health Status** - Service availability monitoring

## Troubleshooting

### Common Issues

**"No data in dashboard"**:
```bash
# Check if ServiceMonitors exist
oc get servicemonitor -n trusted-artifact-signer

# Verify TAS components have monitoring enabled
oc get securesign -n trusted-artifact-signer -o yaml | grep -A1 monitoring
```

**"Grafana won't start"**:
```bash
# Check Grafana Operator status
oc get csv -n openshift-operators | grep grafana-operator

# Check Grafana pod logs
oc logs deployment/tas-grafana-deployment -n trusted-artifact-signer
```

**"Token expired"**:
```bash
# Redeploy to generate new 30-day token
make clean
make deploy
```

### Validation Commands
```bash
# Check all components are running
oc get pods -n trusted-artifact-signer

# Verify monitoring integration
oc get grafana,grafanadatasource,grafanadashboard -n trusted-artifact-signer

# Test Prometheus connectivity
oc exec -n trusted-artifact-signer deployment/tas-grafana-deployment -- \
    curl -k -H "Authorization: Bearer $(oc create token grafana-reader -n trusted-artifact-signer)" \
    https://prometheus-k8s.openshift-monitoring.svc.cluster.local:9091/api/v1/query?query=up
```

## Performance Testing Integration

This monitoring stack is designed to work seamlessly with TAS performance testing:

- **Real-time Metrics**: 10-second refresh for active testing
- **Performance KPIs**: Tracks signatures/second, resource usage, and bottlenecks
- **Component Breakdown**: Identifies which component becomes the bottleneck
- **Resource Planning**: Provides data for capacity planning decisions

