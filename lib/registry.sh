registry.add_user() {
  # Register Docker Registry user
  # $1  User name
  local _username=$1
  local _password

  util.log "Granting Docker Registry access to user '${_username}'"
  # Check to see if the user is already registered
  if [ -f "${registry_dir}/htpasswd" ] && \
     grep -q "${_username}:" "${registry_dir}/htpasswd"; then
    log_error "User account already registered. See: ${registry_dir}/htpasswd"
    exit 1
  fi

  # Generate a random string of 45 characters. Use 8 of them as password.
  _password=$(util.mkpasswd)
  mkdir -p "${registry_dir}/secrets"
  touch "${registry_dir}/secrets/htpasswd"
  docker run --entrypoint htpasswd -v "${registry_dir}/secrets:/run/out" \
    registry:2 -Bb "/run/out/htpasswd" "${_username}" "${_password}"
  # Record the account credentials.
  printf "%s\t%s\n" "${_username}" "${_password}" >> "${registry_dir}/passwd"
  util.log "Credentials saved in ${registry_dir}/passwd"
}

registry.setup() {
  util.log "Setup Docker Registry"
  mkdir -p "${registry_dir}"/{data,secrets,certs}

  util.log "Generating a self-signed certificate"
  if [ ! -f "${registry_dir}/certs/domain.key" ]; then
    openssl req \
      -subj "/CN=registry" \
      -newkey rsa:4096 -nodes -sha256 -keyout "${registry_dir}/certs/domain.key" \
      -x509 -days 7305 -out "${registry_dir}/certs/domain.crt"

    #util.log "Configuring docker to trust registry:5000"
    #sudo mkdir -p "/etc/docker/certs.d/registry:5000"
    #sudo ln -sf "${deployments_dir}/certs/domain.crt" /etc/docker/certs.d/${host_fqdn}:5000/ca.crt
  fi
}
