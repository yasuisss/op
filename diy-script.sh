#!/bin/bash

# 修改默认IP
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate

# TTYD 免登录
sed -i 's/\/bin\/login/\/bin\/login -f root/' feeds/packages/utils/ttyd/files/ttyd.config

# 删除ipv6前缀
sed -i 's/auto//' package/base-files/luci2/bin/config_generate

# 移除要替换的包
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/msd_lite
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/themes/luci-theme-argon-mod
rm -rf feeds/luci/applications/luci-app-argon-config
rm -rf feeds/luci/themes/luci-theme-netgear
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-netdata
rm -rf feeds/luci/applications/luci-app-serverchan
rm -rf feeds/luci/applications/luci-app-smartdns
rm -rf feeds/package/helloworld
rm -rf feeds/packages/lang/golang
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/packages/net/daed
rm -rf feeds/luci/applications/luci-app-daed
rm -rf feeds/packages/utils/dockerd
rm -rf feeds/packages/utils/docker
rm -rf feeds/packages/utils/containerd
rm -rf feeds/packages/utils/runc

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# 添加额外插件
git clone --depth=1 https://github.com/esirplayground/luci-app-poweroff package/luci-app-poweroff
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/luci-app-netdata
git_sparse_clone main https://github.com/Lienol/openwrt-package luci-app-filebrowser luci-app-ssr-mudb-server
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 科学上网插件
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages
git clone https://github.com/Openwrt-Passwall/openwrt-passwall package/passwall-luci
git clone https://github.com/sbwml/openwrt_helloworld package/helloworld
git clone https://github.com/QiuSimons/luci-app-daed package/dae

# Themes
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

# 更改 Argon 主题背景
cp -f $GITHUB_WORKSPACE/images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# SmartDNS
git clone --depth=1 -b master https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns

# msd_lite
git clone --depth=1 https://github.com/ximiTech/luci-app-msd_lite package/luci-app-msd_lite
git clone --depth=1 https://github.com/ximiTech/msd_lite package/msd_lite

# MosDNS (仅保留单个 v5 稳定库)
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns -b v5 package/luci-app-mosdns
git clone --depth=1 https://github.com/sbwml/v2ray-geodata package/v2ray-geodata

# DDNS.to
git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-ddnsto
git_sparse_clone master https://github.com/linkease/nas-packages network/services/ddnsto

# iStore
git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
git_sparse_clone main https://github.com/linkease/istore luci

# 在线用户
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=2s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# x86 型号只显示 CPU 型号
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore

# Add autocore support for armsr-armv8
sed -i 's/TARGET_rockchip/TARGET_rockchip\|\|TARGET_armsr/g' package/lean/autocore/Makefile

# 修改本地时间格式
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(cat "package/lean/default-settings/files/zzz-default-settings" | grep DISTRIB_REVISION= | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by yasui/g" package/lean/default-settings/files/zzz-default-settings

# 取消主题默认设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -print -exec sed -i '/set luci.main.mediaurlbase/d' {} \;

# 测试开启bbr3
sed -i '/exit 0/i echo bbr3 > /proc/sys/net/ipv4/tcp_congestion_control' package/base-files/files/etc/rc.local

# -------------------------------------------------------------------
# 移除旧版损坏的 xtables-addons 并通过 sparse-clone 快速拉取最新版
# -------------------------------------------------------------------
rm -rf feeds/packages/net/xtables-addons package/feeds/packages/xtables-addons
git clone --depth=1 --filter=blob:none --sparse https://github.com/openwrt/packages.git /tmp/owrt-pkgs
cd /tmp/owrt-pkgs && git sparse-checkout set net/xtables-addons
cd - >/dev/null
mv -f /tmp/owrt-pkgs/net/xtables-addons feeds/packages/net/
rm -rf /tmp/owrt-pkgs

# -------------------------------------------------------------------
# 克隆 sbwml 全套 Docker 组件（确保版本统一，100% 解决版本与 cp 报错）
# -------------------------------------------------------------------
rm -rf feeds/packages/utils/dockerd \
       feeds/packages/utils/docker \
       feeds/packages/utils/containerd \
       feeds/packages/utils/runc

git clone --depth=1 https://github.com/sbwml/packages_utils_dockerd feeds/packages/utils/dockerd
git clone --depth=1 https://github.com/sbwml/packages_utils_docker feeds/packages/utils/docker
git clone --depth=1 https://github.com/sbwml/packages_utils_containerd feeds/packages/utils/containerd
git clone --depth=1 https://github.com/sbwml/packages_utils_runc feeds/packages/utils/runc

# 修复 dockerd：关闭 set -u 校验，并让 copy_binaries 直接 return 0
DOCKERD_MK="feeds/packages/utils/dockerd/Makefile"
if [ -f "$DOCKERD_MK" ]; then
    sed -i 's|\./hack/make.sh binary|git init \&\& git config user.name "builder" \&\& git config user.email "builder@local" \&\& git commit --allow-empty -m "init" \&\& sed -i "s/set -e/set +u\nset -e/g" hack/make/binary-daemon \&\& sed -i "/copy_binaries()/a \\treturn 0" hack/make/binary-daemon \&\& ./hack/make.sh binary|g' $DOCKERD_MK
fi

# 重新建立 packages 索引软链接
./scripts/feeds install -a -p packages
