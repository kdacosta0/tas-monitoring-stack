# TAS Monitoring Makefile
ifeq ($(NAMESPACE),)
NAMESPACE = trusted-artifact-signer
endif

.PHONY: help deploy clean

# Default target
help:
	@echo "TAS Monitoring"
	@echo "=============="
	@echo "make deploy              - Deploy monitoring stack"
	@echo "make deploy NAMESPACE=x  - Deploy to custom namespace"
	@echo "make clean               - Remove monitoring stack"
	@echo "make clean NAMESPACE=x   - Remove from custom namespace"
	@echo "make help                - Show this help"
	@echo ""
	@echo "Current namespace: $(NAMESPACE)"

# Deploy monitoring (handles everything)
deploy:
	@chmod +x deploy.sh scripts/*.sh
	@NAMESPACE=$(NAMESPACE) ./deploy.sh

# Clean up deployment
clean:
	@echo "Removing TAS monitoring from namespace: $(NAMESPACE)..."
	@oc delete grafana tas-grafana -n $(NAMESPACE) --ignore-not-found
	@oc delete grafanadatasource tas-prometheus -n $(NAMESPACE) --ignore-not-found
	@oc delete grafanadashboard tas-customer-kpis -n $(NAMESPACE) --ignore-not-found
	@oc delete route tas-grafana-route -n $(NAMESPACE) --ignore-not-found
	@oc delete sa grafana-reader -n $(NAMESPACE) --ignore-not-found
	@echo "Monitoring stack removed from $(NAMESPACE)"