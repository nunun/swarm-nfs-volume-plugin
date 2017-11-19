SWARM_NFS_PLUGIN_SERVER_IP="${SWARM_NFS_PLUGIN_SERVER_IP:-"127.0.0.1"}"
SWARM_NFS_PLUGIN_CLIENT_IP="${SWARM_NFS_PLUGIN_CLIENT_IP:-"127.0.0.1"}"
SWARM_NFS_PLUGIN_VOLUMES="${SWARM_NFS_PLUGIN_VOLUMES:-"nfs_volume"}"
SWARM_NFS_PLUGIN_EXPORT_DIR="${SWARM_NFS_PLUGIN_EXPORT_DIR:-"/exports/swarm-nfs-plugin"}"
SWARM_NFS_PLUGIN_COMPOSE_VERSION="3.0"
EXPORTS_FILE="/etc/exports"
EXPORTS_BACKUP_FILE="/etc/exports.bak"

configure_exports_file() {
        if [ -z "${SWARM_NFS_PLUGIN_CLIENT_IP}" ]; then
                abort "environment vairable 'SWARM_NFS_PLUGIN_CLIENT_IP' is empty."
        fi
        EXPORTS=""
        for v in ${SWARM_NFS_PLUGIN_VOLUMES}; do
                EXPORTS="${EXPORTS}${SWARM_NFS_PLUGIN_EXPORT_DIR}/${v}"
                for a in ${SWARM_NFS_PLUGIN_CLIENT_IP}; do
                        EXPORTS="${EXPORTS} ${a}(rw,sync,no_subtree_check,no_root_squash)"
                done
                EXPORTS="${EXPORTS}"$'\n'
        done
        if [ -f "${EXPORTS_FILE}" ]; then
                if [ ! -f "${EXPORTS_BACKUP_FILE}" ]; then
                        echo "${EXPORTS_FILE} already exists."
                        echo "backup to ${EXPORTS_BACKUP_FILE} ..."
                        sudo cp -v "${EXPORTS_FILE}" "${EXPORTS_BACKUP_FILE}"
                fi
        fi
        sudo mkdir -pv "${SWARM_NFS_PLUGIN_EXPORT_DIR}"
        echo ${EXPORTS} | sudo tee "${EXPORTS_FILE}"
}

configure_compose_file() {
        local dir="${1}"
        local yaml_file="${dir}/docker-compose.yml"
        echo "version: \"${SWARM_NFS_PLUGIN_COMPOSE_VERSION}\""                   >  ${yaml_file}
        echo "volumes: "                                                          >> ${yaml_file}
        for v in ${SWARM_NFS_PLUGIN_VOLUMES}; do
                echo "  ${v}:"                                                    >> ${yaml_file}
                echo "    driver: local"                                          >> ${yaml_file}
                echo "    driver_opts:"                                           >> ${yaml_file}
                echo "      type: nfs4"                                           >> ${yaml_file}
                echo "      o: addr=${SWARM_NFS_PLUGIN_SERVER_IP},rw"             >> ${yaml_file}
                echo "      device: \\\":${SWARM_NFS_PLUGIN_EXPORT_DIR}/${v}\\\"" >> ${yaml_file}

                # NOTE
                # remove directory manually if you want to uninstall.
                sudo mkdir -p "${SWARM_NFS_PLUGIN_EXPORT_DIR}/${v}"
        done
}

on_install() {
        echo "swarm-nfs-plugin: on_install"
        sudo apt-get install nfs-server
        local dir="${1}"
        configure_exports_file
        configure_compose_file "${dir}"
        sudo /etc/init.d/nfs-kernel-server start
}

on_uninstall() {
        echo "swarm-nfs-plugin: on_uninstall"
        sudo /etc/init.d/nfs-kernel-server stop
        sudo apt-get remove nfs-server
}

on_update() {
        echo "swarm-plugin-test: on_update"
        configure_exports_file
        configure_compose_file "${dir}"
        sudo /etc/init.d/nfs-kernel-server restart
}
