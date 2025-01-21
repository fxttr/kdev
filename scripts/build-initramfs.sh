#!/bin/sh

set -e

INITRAMFS_DIR="initramfs"
KERNEL_DIR="linux"
OUTPUT_FILE="initramfs.cpio.gz"

mrpropper() {
	rm -rf $INITRAMFS_DIR $OUTPUT_FILE
}

prepare_initramfs() {
    echo "[+] Preparing initramfs directory structure..."

    mkdir -p $INITRAMFS_DIR/{bin,sbin,etc,proc,sys,usr/{bin,sbin},dev}

    pushd $KERNEL_DIR
    make modules_install INSTALL_MOD_PATH=../initramfs
    popd

    cp $(nix-build -E 'with import <nixpkgs> {}; (busybox.override { enableStatic = true; })' --no-out-link)/bin/busybox $INITRAMFS_DIR/bin
    cp $(nix-build -E 'with import <nixpkgs> {}; pkgsStatic.kmod' --no-out-link)/bin/kmod $INITRAMFS_DIR/bin

    echo "[+] Creating init script..."
    cat << 'EOF' > "$INITRAMFS_DIR/init"
#!/bin/busybox sh

/bin/busybox --install -s

export PATH=/bin/

mknod -m 666 /dev/null c 1 3
mknod -m 666 /dev/tty c 5 0
mknod -m 644 /dev/random c 1 8
mknod -m 644 /dev/urandom c 1 9
mount -t proc none /proc
mount -t sysfs none /sys
mount -t debugfs debugfs /sys/kernel/debug
ln -s /bin/kmod /bin/modprobe
ln -s /bin/kmod /bin/depmod
ln -s /bin/kmod /bin/insmod
ln -s /bin/kmod /bin/lsmod
ln -s /bin/kmod /bin/modinfo
ln -s /bin/kmod /bin/rmmod

KERNEL_VERSION=$(uname -r)
MODULES_DIR="/lib/modules/$KERNEL_VERSION"

if [ -d "$MODULES_DIR" ]; then
    find "$MODULES_DIR" -type f -name "*.ko" | while read -r module; do
        insmod "$module" || echo "Failed to load module: $module"
    done
else
    echo "Modules directory $MODULES_DIR not found!"
fi

cat <<!

Boot took $(cut -d' ' -f1 /proc/uptime) seconds
 _  __               _____       
| |/ /___ _ __ _ __ | ____|_   __
| ' // _ \ '__| '_ \|  _| \ \ / /
| . \  __/ |  | | | | |___ \ V /
|_|\_\___|_|  |_| |_|_____| \_/

Welcome to KernEv

!

# Get a new session to allow for job control and ctrl-* support
exec setsid -c /bin/sh
EOF

    chmod +x "$INITRAMFS_DIR/init"
}

build_initramfs() {
    echo "[+] Building initramfs archive..."

    pushd $INITRAMFS_DIR > /dev/null

    find . | cpio -H newc -o | gzip > "../$OUTPUT_FILE"

    popd > /dev/null
    echo "[+] Initramfs archive created: $OUTPUT_FILE"
}

cleanup() {
    echo "[+] Cleaning up..."
    rm -rf $INITRAMFS_DIR
}

echo "==== Build Initramfs ===="
mrpropper
prepare_initramfs
build_initramfs
cleanup
echo "==== Done ===="
