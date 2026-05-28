GARAGE := docker exec garage /garage

.PHONY: init buckets

init:
	$(eval NODE_ID := $(shell $(GARAGE) node id 2>/dev/null | head -1 | cut -d'@' -f1))
	$(GARAGE) layout assign -z dc1 -c 500G $(NODE_ID)
	$(GARAGE) layout apply --version 1

buckets:
	$(GARAGE) bucket create postgres-backups
	$(GARAGE) bucket create volsync
	$(GARAGE) bucket create media
	$(GARAGE) bucket create loki-chunks
