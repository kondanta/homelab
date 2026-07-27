.PHONY: build up down logs backup

build:
	docker build -t ghcr.io/kondanta/homelab/metal/pgbackup:local .

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

# Run a backup immediately without waiting for the schedule
backup:
	docker compose exec pgbackup /usr/local/bin/backup.sh
