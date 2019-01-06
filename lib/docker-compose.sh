docker_compose.setup() {
  util.log "Generate docker-compose.yml"
  
  # Define shell template variables.
  if [ -f "${deployments_dir}/secrets.sh" ]; then
    util.log "Using ${deployments_dir}/secrets.sh"
  else
    touch "${deployments_dir}/secrets.sh"
    chmod 640 "${deployments_dir}/secrets.sh"
    cat >"${deployments_dir}/secrets.sh" <<EOF
ci_username='admin'
ci_password='$(util.mkpasswd 16)'
db_username='concourse'
db_password='$(util.mkpasswd 16)'
minio_access_key='$(util.mkpasswd 24)'
minio_secret_key='$(util.mkpasswd 64)'
registry_http_secret='$(util.mkpasswd 64)'
EOF
  fi
  
  # shellcheck disable=SC1090
  source "${deployments_dir}/secrets.sh"

  cat >"${script_dir}/docker-compose.yml" <<EOF
# Concourse CI docker compose cluster
#
# Deploy using:  docker-compose up -d
#
# Note: Docker swarm doesn't support privileged containers. Deploy using
# docker-compose until Docker solves the following blocking issues:
#   https://github.com/docker/swarmkit/issues/1030
#   https://github.com/moby/moby/issues/24862
version: '3.1'

networks:
  ci:
    driver: bridge

services:

  registry:
    image: registry:2
    restart: always
    ports:
    - 5000:5000
    networks:
    - ci
    environment:
      REGISTRY_HTTP_SECRET: "${registry_http_secret}"
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /run/registry/secrets/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
      REGISTRY_STORAGE: s3
      REGISTRY_STORAGE_S3_REGION: us-east-1
      REGISTRY_STORAGE_S3_BUCKET: docker-registry
      REGISTRY_STORAGE_S3_REGIONENDPOINT: https://minio:9000/
      REGISTRY_STORAGE_S3_ACCESSKEY: "${minio_access_key}"
      REGISTRY_STORAGE_S3_SECRETKEY: "${minio_secret_key}"
    volumes:
    - ./deployments/registry/certs:/certs:ro
    - ./deployments/registry/secrets:/run/registry/secrets:ro
    - ./deployments/registry/data:/var/lib/registry

  minio:
    image: minio/minio
    restart: unless-stopped
    ports:
    - 9000:9000
    networks:
    - ci
    command: server /data
    volumes:
    - ./deployments/minio/data:/data
    - ./deployments/minio/config:/root/.minio
    environment:
      MINIO_ACCESS_KEY: "${minio_access_key}"
      MINIO_SECRET_KEY: "${minio_secret_key}"

  web:
    # Service will retry until db comes up
    restart: unless-stopped
    image: concourse/concourse
    ports:
    - 8080:8080
    networks:
    - ci
    depends_on:
    - db
    links:
    - db
    command: web
    volumes:
    - ./deployments/web:/concourse-keys
    environment:
      CONCOURSE_EXTERNAL_URL: "${host_url}"
      CONCOURSE_POSTGRES_HOST: db
      CONCOURSE_POSTGRES_DATABASE: concourse
      CONCOURSE_POSTGRES_USER: "${db_username}"
      CONCOURSE_POSTGRES_PASSWORD: "${db_password}"
      CONCOURSE_PUBLICLY_VIEWABLE: "true"
      CONCOURSE_ADD_LOCAL_USER: "${ci_username}:${ci_password}"
      CONCOURSE_MAIN_TEAM_ALLOW_ALL_USERS: "true"
      CONCOURSE_WORKER_EPHEMERAL: "true"

  worker:
    image: concourse/concourse
    restart: unless-stopped
    networks:
    - ci
    # Swarming not possible as workers need to spin out job containers.
    privileged: true
    depends_on:
    - web
    - registry
    - minio
    links:
    - web
    - registry
    - minio
    volumes:
    - ./deployments/worker:/concourse-keys:ro
    environment:
      CONCOURSE_TSA_HOST: web:2222
    command: worker

  db:
    # 9.5-alpine
    image: postgres:9.5
    restart: always
    volumes:
    - ./deployments/db/data:/data
    networks:
    - ci
    environment:
      POSTGRES_DB: concourse
      PGDATA: /data
      POSTGRES_USER: "${db_username}"
      POSTGRES_PASSWORD: "${db_password}"

EOF
}
