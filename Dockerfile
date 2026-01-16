FROM ubuntu:22.04

WORKDIR /workdir

RUN apt update

RUN apt install -y \
  build-essential \
  make gcc g++ \
  clang llvm \
  flex bison gawk \
  git wget curl rsync unzip file time \
  libncurses-dev libssl-dev zlib1g-dev \
  python3 python3-distutils python3-dev\
  python3-setuptools python3-socks python3-unidecode swig \
  cmake ninja-build \
  libelf-dev \
  jq \
  ccache\
  vim \
  libncurses5-dev gettext xsltproc \
  bzip2 \
  patch && rm -rf /var/lib/apt/lists/*

# 创建 builder 用户
RUN useradd -m builder && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


# 克隆源码
RUN git clone https://github.com/liu-jiangyuan/immortalwrt.git
# 在克隆时改权限
RUN chown -R builder:builder /workdir/immortalwrt
# 切换到非 root 用户
USER builder
WORKDIR /workdir/immortalwrt

RUN cat <<'EOF' > .config
# =========================
# Target
# =========================
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_mt7981=y
CONFIG_TARGET_mediatek_mt7981_DEVICE_bt_r320=y

# =========================
# LuCI
# =========================
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y

# =========================
# sing-box
# =========================
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_luci-app-sing-box=y
CONFIG_PACKAGE_luci-i18n-sing-box-zh-cn=y

# =========================
# Docker
# =========================
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_luci-app-docker=y
CONFIG_PACKAGE_luci-i18n-docker-zh-cn=y

# =========================
# 必要依赖（Docker 运行必需）
# =========================
CONFIG_PACKAGE_containerd=y
CONFIG_PACKAGE_runc=y
CONFIG_PACKAGE_cgroupfs-mount=y
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-bridge=y
CONFIG_PACKAGE_kmod-br-netfilter=y
CONFIG_PACKAGE_kmod-nf-nat=y
CONFIG_PACKAGE_kmod-ipt-nat=y
CONFIG_PACKAGE_kmod-iptable-nat=y

# =========================
# 编译优化
# =========================
CONFIG_CCACHE=y
CONFIG_DEVEL=y
CONFIG_BUILD_LOG=y

# =========================
# 明确禁用（防止冲突）
# =========================
# CONFIG_PACKAGE_passwall is not set
# CONFIG_PACKAGE_passwall2 is not set
# CONFIG_PACKAGE_luci-app-passwall is not set
# CONFIG_PACKAGE_luci-app-passwall2 is not set

EOF

# 确认文件存在并可写
RUN ls -l .config

# 或者直接在容器内生成默认配置：
RUN make defconfig

# 更新和安装 feeds
RUN ./scripts/feeds update -a
RUN ./scripts/feeds install -a

# 编译
RUN make -j6