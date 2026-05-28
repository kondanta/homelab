DATA_DIR := /home/pi/services/redis/data
REDIS_UID := 999
REDIS_GID := 1000

.PHONY: setup up down logs

setup:
	mkdir -p $(DATA_DIR)
	chown $(REDIS_UID):$(REDIS_GID) $(DATA_DIR)
	chmod 750 $(DATA_DIR)

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f
