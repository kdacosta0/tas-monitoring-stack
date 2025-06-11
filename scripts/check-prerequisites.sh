#!/bin/bash
# Check prerequisites for TAS monitoring deployment

echo ""
echo -e "${BLUE}Checking prerequisites...${NC}"

# List of required ServiceMonitors
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

# Check each ServiceMonitor
for monitor in "${REQUIRED_SERVICEMONITORS[@]}"; do
    if oc get servicemonitor "$monitor" -n "$NAMESPACE" &>/dev/null; then
        FOUND_MONITORS+=("$monitor")
        echo -e "   ${GREEN}✓${NC} ServiceMonitor: $monitor"
    else
        MISSING_MONITORS+=("$monitor")
        echo -e "   ${RED}✗${NC} ServiceMonitor: $monitor"
    fi
done

# Summary and warning
echo ""
if [ ${#MISSING_MONITORS[@]} -eq 0 ]; then
    echo -e "${GREEN}All required ServiceMonitors are present!${NC}"
else
    echo -e "${YELLOW}WARNING: ${#MISSING_MONITORS[@]} ServiceMonitor(s) missing!${NC}"
    echo -e "${YELLOW}Missing: ${MISSING_MONITORS[*]}${NC}"
    echo ""
    echo -e "${YELLOW}Metrics from these components won't be available.${NC}"
    echo ""
    
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 1
    fi
fi