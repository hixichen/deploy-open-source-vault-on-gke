APP_NAME=oss-vault-audit

build: Dockerfile
	docker build --build-arg ASSET_DIR=. \
				 --build-arg UID=100 \
				 --build-arg GID=1000 \
				 --tag $(APP_NAME) .