
minio.setup() {
  util.log "Setup Minio"
  mkdir -p "${minio_dir}"/{data,config}
}

