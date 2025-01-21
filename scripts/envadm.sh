DEBIAN_VERSION=${DEBIAN_VERSION:-12}
ARCH=${ARCH:-amd64}
BUILD_DIR=$ENV_DIR/${BUILD_DIR:-build}
VM_FILENAME=${VM_FILENAME:-vm.qcow2}
VM_PATH=$BUILD_DIR/$VM_FILENAME
BOOTSTRAP=${BOOTSTRAP:-false}

check_env() {
        if [ ! -f "$VM_PATH" ]; then
                BOOTSTRAP=true
        fi
}

bootstrap() {
        mkdir -p $BUILD_DIR
        
        curl -L http://cdimage.debian.org/cdimage/cloud/bookworm/daily/latest/debian-${DEBIAN_VERSION}-nocloud-${ARCH}-daily.qcow2 -O $VM_PATH
}

check_env

[ "$BOOTSTRAP" = true ] && bootstrap
