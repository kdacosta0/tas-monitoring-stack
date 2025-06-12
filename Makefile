# TAS Monitoring Makefile

.PHONY: help status deploy clean

# Default target
help:
	@echo "TAS Monitoring"
	@echo "=============="
	@echo "make deploy              - Deploy monitoring stack"
	@echo "make clean               - Remove monitoring stack"
	@echo "make help                - Show this help"
	@echo ""

status:
	@oc get grafana,grafanadatasource,grafanadashboard -n trusted-artifact-signer

# Deploy monitoring (handles everything)
deploy:
	@chmod +x deploy.sh scripts/*.sh
	./deploy.sh

# Clean up deployment
clean:
	@echo "Removing TAS monitoring from namespace: trusted-artifact-signer"
	@oc delete grafana tas-grafana -n trusted-artifact-signer --ignore-not-found
	@oc delete grafanadatasource tas-prometheus -n trusted-artifact-signer --ignore-not-found
	@oc delete grafanadashboard tas-performance-kpis -n trusted-artifact-signer --ignore-not-found
	@oc delete route tas-grafana-route -n trusted-artifact-signer --ignore-not-found
	@oc delete sa grafana-reader -n trusted-artifact-signer --ignore-not-found
	@echo "Monitoring stack removed from trusted-artifact-signer"