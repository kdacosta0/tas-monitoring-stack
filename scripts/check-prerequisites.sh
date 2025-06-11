#!/bin/bash
# Check prerequisites for TAS monitoring deployment

echo ""
echo -e "${BLUE}Checking prerequisites...${NC}"

# 1. Check Grafana Operator
echo -e "\n${BLUE}Checking Grafana Operator...${NC}"
if oc get csv -n openshift-operators | grep -q "grafana-operator.*Succeeded"; then
    GRAFANA_VERSION=$(oc get csv -n openshift-operators | grep grafana-operator | awk '{print $1}')
    echo -e "    Grafana Operator: ${GREEN}installed${NC} ($GRAFANA_VERSION)"
else
    echo -e "    Grafana Operator: ${RED}not found${NC}"
    echo -e "${RED}ERROR: Grafana Operator is required!${NC}"
    echo -e "Install it from OperatorHub: ${YELLOW}Grafana Operator (Community)${NC}"
    exit 1
fi


# 2. Check Securesign deployment and monitoring settings
echo -e "\n${BLUE}Checking RHTAS Operator and Securesign deployment...${NC}"

# First check if namespace exists
if ! oc get namespace "$NAMESPACE" &>/dev/null; then
    echo -e "    Namespace: ${RED}$NAMESPACE not found${NC}"
    echo -e "${RED}ERROR: Namespace $NAMESPACE does not exist!${NC}"
    exit 1
fi

# Check if Securesign CRD exists
if oc get csv -n openshift-operators | grep -q "rhtas-operator.*Succeeded"; then
    RHTAS_VERSION=$(oc get csv -n openshift-operators | grep rhtas-operator | awk '{print $1}')
    echo -e "    RHTAS Operator: ${GREEN}installed${NC} ($RHTAS_VERSION)"
fi

# Now check for Securesign instances
SECURESIGN_COUNT=$(oc get securesign -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)

if [ "$SECURESIGN_COUNT" -eq 0 ]; then
    echo -e "    Securesign: ${RED}not found${NC}"
    echo -e "${RED}ERROR: No Securesign instance found in namespace $NAMESPACE${NC}"
    echo -e "${YELLOW}Deploy TAS first before setting up monitoring.${NC}"
    exit 1
elif [ "$SECURESIGN_COUNT" -gt 1 ]; then
    echo -e "    Securesign: ${YELLOW}Multiple instances found${NC}"
    # List all instances
    oc get securesign -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name --no-headers
    # Use the first one
    SECURESIGN_NAME=$(oc get securesign -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    echo -e "    Using: ${GREEN}$SECURESIGN_NAME${NC}"
else
    SECURESIGN_NAME=$(oc get securesign -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    echo -e "    Securesign: ${GREEN}$SECURESIGN_NAME${NC}"
fi
    
# Check monitoring enabled for each component
echo -e "\n${BLUE}Checking monitoring settings...${NC}"
COMPONENTS=("fulcio" "rekor" "trillian" "ctlog" "tsa")
MONITORING_ISSUES=()

for component in "${COMPONENTS[@]}"; do
    MONITORING_ENABLED=$(oc get securesign "$SECURESIGN_NAME" -n "$NAMESPACE" \
        -o jsonpath="{.spec.$component.monitoring.enabled}" 2>/dev/null)
    
    if [ "$MONITORING_ENABLED" == "true" ]; then
        echo -e "    $component monitoring: ${GREEN}enabled${NC}"
    else
        echo -e "    $component monitoring: ${RED}disabled${NC}"
        MONITORING_ISSUES+=("$component")
    fi
done

if [ ${#MONITORING_ISSUES[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}WARNING: Monitoring is disabled for: ${MONITORING_ISSUES[*]}${NC}"
    echo -e "${YELLOW}You should enable monitoring in your Securesign CR for these components.${NC}"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 1
    fi
fi

# 3. Check ServiceMonitors
echo -e "\n${BLUE}Checking ServiceMonitors...${NC}"
REQUIRED_SERVICEMONITORS=(
    "fulcio-server"
    "rekor-server"
    "trillian-logsigner"
    "trillian-logserver"
    "ctlog"
    "tsa-server"
)

MISSING_MONITORS=()
FOUND_MONITORS=()

for monitor in "${REQUIRED_SERVICEMONITORS[@]}"; do
    if oc get servicemonitor "$monitor" -n "$NAMESPACE" &>/dev/null; then
        FOUND_MONITORS+=("$monitor")
        echo -e "    ServiceMonitor $monitor: ${GREEN}found${NC}"
    else
        MISSING_MONITORS+=("$monitor")
        echo -e "    ServiceMonitor $monitor: ${RED}missing${NC}"
    fi
done

# 4. Check OpenShift monitoring
echo -e "\n${BLUE}Checking OpenShift monitoring...${NC}"
if oc get pods -n openshift-monitoring | grep -q prometheus-k8s; then
    echo -e "    Platform Prometheus: ${GREEN}running${NC}"
else
    echo -e "    Platform Prometheus: ${RED}not found${NC}"
    echo -e "${RED}ERROR: OpenShift monitoring stack is required!${NC}"
    exit 1
fi

# Check if user workload monitoring is enabled
if oc get pods -n openshift-user-workload-monitoring &>/dev/null && \
   oc get pods -n openshift-user-workload-monitoring | grep -q prometheus-user-workload; then
    echo -e "    User workload monitoring: ${GREEN}enabled${NC}"
else
    echo -e "    User workload monitoring: ${YELLOW}not enabled${NC}"
    echo -e "${YELLOW}You may need to enable user workload monitoring.${NC}"
fi

# Summary
echo -e "\n${BLUE}Summary:${NC}"
echo -e "    Namespace: $NAMESPACE"
echo -e "    Securesign: $SECURESIGN_NAME"
echo -e "    Found ServiceMonitors: ${#FOUND_MONITORS[@]}/${#REQUIRED_SERVICEMONITORS[@]}"

if [ ${#MISSING_MONITORS[@]} -eq 0 ] && [ ${#MONITORING_ISSUES[@]} -eq 0 ]; then
    echo -e "\n${GREEN}All prerequisites satisfied!${NC}"
else
    if [ ${#MISSING_MONITORS[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}WARNING: Some ServiceMonitors are missing.${NC}"
        echo -e "${YELLOW}Metrics from these components won't be available: ${MISSING_MONITORS[*]}${NC}"
    fi
    if [ ${#MONITORING_ISSUES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}WARNING: Some components have monitoring disabled.${NC}"
        echo -e "${YELLOW}Enable monitoring for: ${MONITORING_ISSUES[*]} and redeploy.${NC}"
    fi
fi

echo ""