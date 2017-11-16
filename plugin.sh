SWARM_NFS_PLUGIN_CLIENT_IP_LIST="${SWARM_NFS_PLUGIN_CLIENT_IP_LIST:-"127.0.0.1"}"
SWARM_NFS_PLUGIN_EXPORT_DIR="${SWARM_NFS_PLUGIN_EXPORT_DIR:-"/exports/swarm-nfs-plugin"}"
EXPORTS_FILE="/etc/exports"
EXPORTS_BACKUP_FILE="/etc/exports.bak"

configure_exports_file() {
        if [ -z "${SWARM_NFS_PLUGIN_CLIENT_IP}" ]; then
                abort "environment vairable 'SWARM_NFS_PLUGIN_CLIENT_IP' is empty."
        fi
        EXPORTS=""
        for a in ${SWARM_NFS_PLUGIN_CLIENT_IP}; do
                EXPORTS="${EXPORTS} ${a}(rw,sync,no_subtree_check,no_root_squash)"
        done
        if [ -f "${EXPORTS_FILE}" ]; then
                if [ ! -f "${EXPORTS_BACKUP_FILE}" ]; then
                        echo "${EXPORTS_FILE} already exists."
                        echo "backup to ${EXPORTS_BACKUP_FILE} ..."
                        cp -v "${EXPORTS_FILE}" "${EXPORTS_BACKUP_FILE}"
                fi
        fi
        mkdir -pv "${SWARM_NFS_PLUGIN_EXPORT_DIR}"
        echo "${SWARM_NFS_PLUGIN_EXPORT_DIR} ${EXPORTS}" > "${EXPORTS_FILE}"
}

on_install() {
        echo "swarm-nfs-plugin: on_install"
        apt-get install nfs-server
        configure_exports_file
        /etc/init.d/nfs-kernel-server start
}

on_uninstall() {
        echo "swarm-nfs-plugin: on_uninstall"
        /etc/init.d/nfs-kernel-server stop
        apt-get remove nfs-server
}

on_update() {
        echo "swarm-plugin-test: on_update"
        configure_exports_file
        /etc/init.d/nfs-kernel-server restart
}
