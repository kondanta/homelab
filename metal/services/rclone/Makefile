.PHONY: build configure up down logs sync

build:
	docker compose build

# Run interactively to set up garage + proton remotes in rclone.conf.
# Run this before 'make up'. Creates rclone.conf if it doesn't exist.
configure:
	mkdir -p config
	docker compose run --rm --entrypoint rclone rclone config

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

# Trigger a sync immediately without waiting for the schedule
sync:
	docker compose exec rclone /usr/local/bin/sync.sh
