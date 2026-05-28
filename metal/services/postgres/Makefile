DATA_DIR := /home/pi/services/postgres/data
POSTGRES_UID := 999
POSTGRES_GID := 999

.PHONY: setup up down logs

setup:
	mkdir -p $(DATA_DIR)
	chown $(POSTGRES_UID):$(POSTGRES_GID) $(DATA_DIR)
	chmod 700 $(DATA_DIR)

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f
