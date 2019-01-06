
minio.setup() {
  util.log "Setup Minio"
  mkdir -p "${minio_dir}"/{data,config/certs}

  util.log "Generating a self-signed certificate"
  if [ ! -f "${minio_dir}/config/certs/domain.key" ]; then
    openssl req \
      -subj "/CN=*.minio" \
      -newkey rsa:4096 -nodes -sha256 -keyout "${minio_dir}/config/certs/private.key" \
      -x509 -days 7305 -out "${minio_dir}/config/certs/public.crt"

    #util.log "Configuring docker to trust registry:5000"
    #sudo mkdir -p "/etc/docker/certs.d/registry:5000"
    #sudo ln -sf "${deployments_dir}/certs/domain.crt" /etc/docker/certs.d/${host_fqdn}:5000/ca.crt
  fi
}

