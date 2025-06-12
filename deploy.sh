#!/bin/bash
# TAS Monitoring Deployment Script
# Deploys TAS monitoring with dynamic token generation

set -e

# Configuration
NAMESPACE="trusted-artifact-signer"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
MANIFESTS_DIR="${SCRIPT_DIR}/manifests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Deploying TAS Monitoring ===${NC}"

# Source prerequisite check
source "${SCRIPT_DIR}/scripts/check-prerequisites.sh"

# Step 1: Label namespace for cluster monitoring
echo ""
echo -e "${BLUE}Step 1: Enabling cluster monitoring for namespace...${NC}"
oc label namespace $NAMESPACE openshift.io/cluster-monitoring=true --overwrite

# Step 2: Create ServiceAccount and get token
echo ""
echo -e "${BLUE}Step 2: Creating ServiceAccount for Grafana...${NC}"
oc apply -f "${MANIFESTS_DIR}/rbac/grafana-serviceaccount.yaml"
oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-reader -n $NAMESPACE

# Generate token
TOKEN=$(oc create token grafana-reader -n $NAMESPACE --duration=720h)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}ERROR: Failed to generate token${NC}"
    exit 1
fi

# Step 3: Deploy Grafana instance
echo ""
echo -e "${BLUE}Step 3: Deploying Grafana instance...${NC}"
oc apply -f "${MANIFESTS_DIR}/grafana/01-grafana-instance.yaml"

# Step 4: Deploy datasource with dynamic token
echo ""
echo -e "${BLUE}Step 4: Deploying Prometheus datasource...${NC}"
sed "s/\${TOKEN}/${TOKEN}/g" "${MANIFESTS_DIR}/grafana/02-grafana-datasource.yaml.template" | oc apply -f -

# Step 5: Deploy dashboard
echo ""
echo -e "${BLUE}Step 5: Deploying TAS dashboard...${NC}"
oc apply -f "${MANIFESTS_DIR}/grafana/03-grafana-dashboard.yaml"

# Step 6: Create route
echo ""
echo -e "${BLUE}Step 6: Creating Grafana route...${NC}"
oc apply -f "${MANIFESTS_DIR}/grafana/04-grafana-route.yaml"

# Wait for deployment
echo ""
echo -e "${BLUE}Waiting for Grafana to be ready...${NC}"
oc wait --for=condition=available deployment/tas-grafana-deployment -n $NAMESPACE --timeout=300s

# Get the route
GRAFANA_URL=$(oc get route tas-grafana-route -n $NAMESPACE -o jsonpath='{.spec.host}')

# Summary
echo ""
echo -e "${GREEN}=== TAS Monitoring deployed successfully! ===${NC}"
echo ""
echo -e "${BLUE}Access your dashboard:${NC}"
echo "   URL: https://$GRAFANA_URL"
echo "   Login: admin / admin"
echo ""
echo -e "${YELLOW}Security reminders:${NC}"
echo -e "   • Token expires in 30 hours - redeploy when needed"
echo -e "   • Change default Grafana admin password"
echo ""

# Show monitoring status if there were missing monitors
if [ ${#MISSING_MONITORS[@]} -gt 0 ]; then
    echo -e "${YELLOW}Remember: Missing ServiceMonitors for: ${MISSING_MONITORS[*]}${NC}"
    echo -e "${YELLOW}   Metrics from these components won't appear in dashboards${NC}"
    echo ""
fi