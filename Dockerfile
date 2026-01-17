############################################
# Stage 1: Builder
############################################
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CCACHE_DIR=/ccache

WORKDIR /workdir

RUN apt update && apt install -y \
  build-essential \
  gcc g++ make \
  flex bison gawk \
  git wget curl rsync unzip file time \
  libncurses-dev libssl-dev zlib1g-dev \
  python3 python3-dev python3-setuptools \
  swig \
  libelf-dev \
  jq \
  ccache \
  libncurses5-dev gettext xsltproc \
  bzip2 patch \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# builder 用户
RUN useradd -m builder
RUN mkdir /ccache && chown builder:builder /ccache

USER builder
WORKDIR /workdir

# 克隆源码
RUN git clone https://github.com/liu-jiangyuan/immortalwrt.git
WORKDIR /workdir/immortalwrt

############################################
# feeds（单独一层，利于缓存）
############################################
RUN ./scripts/feeds update -a && ./scripts/feeds install -a

############################################
# 写入 config
############################################
RUN cat <<'EOF' > .config
# =========================
# Target
# =========================
CONFIG_TARGET_mediatek=y
CONFIG_TARGET_mediatek_filogic=y
CONFIG_TARGET_mediatek_filogic_DEVICE_bt_r320=y

# =========================
# LuCI
# =========================
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y

# =========================
# sing-box + LuCI
# =========================
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_luci-app-sing-box=y
CONFIG_PACKAGE_luci-i18n-sing-box-zh-cn=y

# sing-box 基础网络依赖
CONFIG_PACKAGE_iptables=y
CONFIG_PACKAGE_iptables-nft=y
CONFIG_PACKAGE_ipset=y

CONFIG_PACKAGE_kmod-nf-tproxy=y
CONFIG_PACKAGE_kmod-ipt-ipset=y

# =========================
# Docker
# =========================
CONFIG_PACKAGE_docker=y
CONFIG_PACKAGE_dockerd=y
CONFIG_PACKAGE_containerd=y
CONFIG_PACKAGE_runc=y
CONFIG_PACKAGE_cgroupfs-mount=y

# Docker 网络必需内核模块
CONFIG_PACKAGE_kmod-veth=y
CONFIG_PACKAGE_kmod-bridge=y
CONFIG_PACKAGE_kmod-br-netfilter=y

CONFIG_PACKAGE_kmod-nf-conntrack=y
CONFIG_PACKAGE_kmod-nf-nat=y
CONFIG_PACKAGE_kmod-ipt-nat=y
CONFIG_PACKAGE_kmod-ipt-filter=y

# LuCI Docker 管理
CONFIG_PACKAGE_luci-app-dockerman=y
CONFIG_PACKAGE_luci-i18n-dockerman-zh-cn=y

# =========================
# 编译优化（本地 OK，Actions 也能用）
# =========================
CONFIG_CCACHE=y
CONFIG_DEVEL=y
CONFIG_BUILD_LOG=y

# =========================
# 明确禁用 PassWall（避免拉一堆核心）
# =========================
# CONFIG_PACKAGE_passwall is not set
# CONFIG_PACKAGE_passwall2 is not set
# CONFIG_PACKAGE_luci-app-passwall is not set
# CONFIG_PACKAGE_luci-app-passwall2 is not set

EOF

RUN make defconfig

############################################
# 下载源码包
############################################
RUN make download -j$(nproc)

############################################
# 编译
############################################
RUN make -j4

############################################
# Stage 2: Export firmware
############################################
FROM alpine:3.19 AS output
COPY --from=builder /workdir/immortalwrt/bin /output
