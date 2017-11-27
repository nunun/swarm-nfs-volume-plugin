SWARM_NFS_VOLUME_PLUGIN_NFS_SERVER_IP="${SWARM_NFS_VOLUME_PLUGIN_NFS_SERVER_IP:-"127.0.0.1"}"
SWARM_NFS_VOLUME_PLUGIN_NFS_CLIENT_IP="${SWARM_NFS_VOLUME_PLUGIN_NFS_CLIENT_IP:-"127.0.0.1"}"
SWARM_NFS_VOLUME_PLUGIN_NFS_EXTERNAL_VOLUMES="${SWARM_NFS_VOLUME_PLUGIN_NFS_EXTERNAL_VOLUMES:-"nfs_volume"}"
SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR="${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR:-"/exports/swarm-nfs-plugin"}"
SWARM_NFS_VOLUME_PLUGIN_VOLUME_LABEL="${SWARM_NFS_VOLUME_PLUGIN_VOLUME_LABEL:-"swarm-nfs-volume"}"
EXPORTS_FILE="/etc/exports"
EXPORTS_BACKUP_FILE="/etc/exports.bak"

on_install() {
        log_debug "swarm-nfs-volume-plugin: on_install (${*})"
        sudo apt-get install nfs-server
        local dir="${1}"
        configure_exports_file
        sudo /etc/init.d/nfs-kernel-server start
        sleep 2 # NOTE sleep a moment ...
        create_nfs_volumes
}

on_uninstall() {
        log_debug "swarm-nfs-volume-plugin: on_uninstall (${*})"
        remove_nfs_volumes
        sleep 2 # NOTE sleep a moment ...
        sudo /etc/init.d/nfs-kernel-server stop
        sudo apt-get remove nfs-server
}

on_reinstall() {
        log_debug "swarm-nfs-volume-plugin: on_reinstall (${*})"
        configure_exports_file
        sudo /etc/init.d/nfs-kernel-server restart
        sleep 2 # NOTE sleep a moment ...
        create_nfs_volumes
}

on_terraform() {
        log_debug "swarm-nfs-volume-plugin: on_terraform (${*})"
        local host="${2}"
        [ -n "${host}" ] && create_nfs_volumes "${host}"
}

on_unterraform() {
        log_debug "swarm-nfs-volume-plugin: on_unterraform (${*})"
        local host="${2}"
        [ -n "${host}" ] && remove_nfs_volumes "${host}"
}

on_update() {
        log_debug "swarm-nfs-volume-plugin: on_update (${*})"
        # nothing to do
}

on_compose() {
        log_debug "swarm-nfs-volume-plugin: on_compose (${*})"
        # nothing to do
}

###############################################################################
###############################################################################
###############################################################################

configure_exports_file() {
        log_debug "configure_exports_file()"
        if [ -z "${SWARM_NFS_VOLUME_PLUGIN_NFS_CLIENT_IP}" ]; then
                abort "environment vairable 'SWARM_NFS_VOLUME_PLUGIN_NFS_CLIENT_IP' is empty."
        fi
        EXPORTS=""
        for v in ${SWARM_NFS_VOLUME_PLUGIN_NFS_EXTERNAL_VOLUMES}; do
                EXPORTS="${EXPORTS}${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR}/${v}"
                for a in ${SWARM_NFS_VOLUME_PLUGIN_NFS_CLIENT_IP}; do
                        EXPORTS="${EXPORTS} ${a}(rw,sync,no_subtree_check,no_root_squash)"
                done
                EXPORTS="${EXPORTS}\n"
        done
        if [ -f "${EXPORTS_FILE}" ]; then
                if [ ! -f "${EXPORTS_BACKUP_FILE}" ]; then
                        log_info "${EXPORTS_FILE} already exists."
                        log_info "backup to ${EXPORTS_BACKUP_FILE} ..."
                        sudo cp -v "${EXPORTS_FILE}" "${EXPORTS_BACKUP_FILE}"
                fi
        fi
        sudo mkdir -pv "${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR}"
        echo -e ${EXPORTS} | sudo tee "${EXPORTS_FILE}"
}

create_nfs_volumes() {
        log_debug "create_nfs_volumes()"
        local host="${1}"
        local args="${host:+"arbitrary -H "}${host}"
        remove_nfs_volumes "${host}"
        log_info "creating nfs volumes labelled '${SWARM_NFS_VOLUME_PLUGIN_VOLUME_LABEL}' ..."
        for v in ${SWARM_NFS_VOLUME_PLUGIN_NFS_EXTERNAL_VOLUMES}; do
                log_info "volume '${v}' ... (${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR}/${v} on ${SWARM_NFS_VOLUME_PLUGIN_NFS_SERVER_IP} by nfs4)"
                swarm_pssh ${args} "docker volume create --name ${v} --driver local --opt type=nfs4 --opt o=addr=${SWARM_NFS_VOLUME_PLUGIN_NFS_SERVER_IP},rw --opt device=:${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR}/${v} --label=${SWARM_NFS_VOLUME_PLUGIN_VOLUME_LABEL}"
        done
        log_info "done."
}

remove_nfs_volumes() {
        log_debug "remove_nfs_volumes()"
        local host="${1}"
        local args="${host:+"arbitrary -H "}${host}"
        log_info "removing nfs volumes labelled '${SWARM_NFS_VOLUME_PLUGIN_VOLUME_LABEL}' ..."
        swarm_pssh ${args} --inline "docker volume rm \`docker volume ls -q -f label=swarm-nfs-volume\`" \
                > /tmp/swarm-nfs-volume-plugin.remove.log || :
        log_info "done."
}

#local dir="${1}"
#local compose_yml="${1}"
#configure_compose_file "${dir}" "${compose_yml}"
#configure_compose_file() {
#        local dir="${1}"
#        local compose_yml="${2}"
#        local volumes_yml="${dir}/volumes.yml"
#        local merging_yml="${dir}/merging.yml"
#        local volumes=`docker-compose -f "${compose_yml}" config --volumes`
#        local exports=""
#
#        # create volumes.yml
#        echo "version: \"${SWARM_NFS_VOLUME_PLUGIN_COMPOSE_VERSION}\"" >  ${volumes_yml}
#        echo "volumes: "                                        >> ${volumes_yml}
#        for v in ${volumes}; do
#                local found=""
#                for f in ${SWARM_NFS_VOLUME_PLUGIN_NFS_EXTERNAL_VOLUMES}; do
#                        if [ "${v}" = "${f}" ]; then
#                                found="1"
#                                break
#                        fi
#                done
#                if [ -n "${found}" ]; then
#                        echo "  ${v}:"                                            >> ${volumes_yml}
#                        echo "    driver: local"                                  >> ${volumes_yml}
#                        echo "    driver_opts:"                                   >> ${volumes_yml}
#                        echo "      type: nfs4"                                   >> ${volumes_yml}
#                        echo "      o: addr=${SWARM_NFS_VOLUME_PLUGIN_NFS_SERVER_IP},rw"     >> ${volumes_yml}
#                        echo "      device: :${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR}/${v}" >> ${volumes_yml}
#
#                        # NOTE
#                        # remove directory manually if you want to uninstall.
#                        sudo mkdir -p "${SWARM_NFS_VOLUME_PLUGIN_EXPORT_DIR}/${v}"
#
#                        # NOTE
#                        # add to exports
#                        exports="${exports} ${v}"
#                fi
#        done
#
#        # merge .current.yml and volumes.yml into .current.yml.
#        if [ -n "${exports}" ]; then
#                docker-compose -f "${compose_yml}" -f "${volumes_yml}" config > "${merging_yml}"
#                cp "${merging_yml}" "${compose_yml}"
#                log_info "nfs volumes are added to compose:${exports}"
#                log_info "compose updated."
#        fi
#}
