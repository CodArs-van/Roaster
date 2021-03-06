# ================================================================
# Install Packages
# ================================================================

for i in pkg-{skip,all}; do
    [ -e $STAGE/$i ] && ( set -xe
        for skip in true false; do
        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE $($skip && echo --skip-broken) && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done
        done

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            echo "
                devtoolset-{6,7,8}{,-*}
                llvm-toolset-7{,-*}

                qpid-cpp-client{,-*}
                {gcc,distcc,ccache}{,-*}
                {openmpi,mpich-3.{0,2}}{,-devel,-doc,-debuginfo}
                java-1.8.0-openjdk{,-*}
                octave{,-*}
                {gdb,gperf,gperftools,valgrind,perf,{l,s}trace}{,-*}
                {make,ninja-build,cmake{,3},autoconf,libtool}{,-*}
                {ant,maven}{,-*}
                {git,rh-git218,subversion,mercurial}{,-*}
                valgrind{,-*}
                doxygen{,-*}
                pandoc{,-*}
                swig{,-*}
                sphinx{,-*}

                vim{,-*}
                dos2unix{,-*}

                {bash,fish,zsh,mosh,tmux}{,-*}
                {bc,sed,man,pv,time,which}{,-*}
                {parallel,jq}{,-*}
                {tree,whereami,mlocate,lsof}{,-*}
                {ftp{,lib},telnet,tftp,rsh}{,-debuginfo}
                {h,if,io,latency,power,tip}top{,-*}
                procps-ng{,-*}
                {wget,axel,curl,net-tools}{,-*}
                {f,tc,dhc,libo,io}ping{,-*}
                hping3{,-*}
                {traceroute,mtr,rsync,tcpdump,whois,net-snmp}{,-*}
                torsocks{,-*}
                {bridge-,core,crypto-,elf,find,ib,ip,pci,usb,yum-}utils{,-*}
                util-linux{,-*}
                moreutils{,-debuginfo}
                papi{,-*}
                rpmdevtools
                rpm-build
                cyrus-imapd{,-*}
                GeoIP{,-*}
                {device-mapper,lvm2}{,-*}
                {d,sys}stat{,-*}
                {lm_sensors,hddtemp,smartmontools,lsscsi}{,-*}
                {{e2fs,btrfs-,xfs,ntfs}progs,xfsdump,nfs-utils}{,-*}
                fuse{,-devel,-libs}
                dd{,_}rescue{,-*}
                {docker-ce,container-selinux}{,-*}
                createrepo{,_c}{,-*}
                environment-modules{,-*}
                munge{,-*}

                scl-utils{,-*}

                ncurses{,-*}
                hwloc{,-*}
                numa{ctl,d}{,-*}
                icu{,-*}
                {glibc{,-devel},libgcc}
                {gmp,mpfr,libmpc}{,-*}
                gperftools{,-*}
                lib{asan{,3},tsan,ubsan}{,-*}
                lib{exif,jpeg-turbo,tiff,png,gomp,gphoto2}{,-*}
                OpenEXR{,-*}
                {libv4l,v4l-utils}{,-*}
                libunicap{,gtk}{,-*}
                libglvnd{,-*}
                lib{dc,raw}1394{,-*}
                {zlib,libzip,{,lib}zstd,lz4,{,p}{bzip2,xz},pigz,cpio,tar,snappy,unrar}{,-*}
                lib{telnet,ssh{,2},curl,aio,ffi,edit,icu,xslt}{,-*}
                boost{,-*}
                {flex,cups,bison,antlr}{,-*}
                open{blas,cv,ldap,ni,ssh,ssl}{,-*}
                {atlas,eigen3}{,-*}
                lapack{,64}{,-*}
                {libsodium,mbedtls}{,-*}
                libev{,-devel,-source,-debuginfo}
                {asciidoc,gettext,xmlto,c-ares,pcre{,2}}{,-*}
                librados2{,-*}
                {gflags,glog,gmock,gtest,protobuf}{,-*}
                {redis,hiredis}{,-*}
                zeromq{,-*}
                ImageMagick{,-*}
                qt5-*
                yasm{,-*}
                gperf{,-*}
                docbook{,5,2X}{,-*}
                asciidoc{,-*}
                txt2man
                nagios{,-selinux,-devel,-debuginfo,-plugins-all}
                {nrpe,nsca}
                {collectd,rrdtool,pnp4nagios}{,-*}
                cuda
                libcudnn7{,-devel} libnccl{,-devel,-static}
                nvidia-docker2

                hdf5{,-*}
                {leveldb,lmdb}{,-*}
                mariadb{,-*}
                rh-postgresql10{,-postgresql{,-*}}

                {fio,{file,sys}bench}{,-*}

                {,pam_}krb5{,-*}
                {sudo,nss,sssd,authconfig}{,-*}

                gitlab-runner

                youtube-dl

                privoxy{,-*}

                wine

                libselinux{,-*}
                policycoreutils{,-*}
                se{troubleshoot,tools}{,-*}
                selinux-policy{,-*}

                mod_authnz_*

                cabextract{,-*}

                anaconda{,-*}
                libreoffice{,-*}
                perl{,-*}
                python{,36}{,-devel,-debug{,info}}
                {python27,rh-python36}{,-python-{devel,debug{,info}}}
                {python{2,36},{python27,rh-python36}-python}-pip
                {ruby,rh-ruby25}{,-*}
                lua{,-*}

                *-fonts{,-*}
            " | xargs -n10 echo "$RPM_INSTALL $([ $i = pkg-skip ] && echo --skip-broken)" | bash && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        which parallel 2>/dev/null && sudo parallel --will-cite < /dev/null

        # ------------------------------------------------------------

        # Remove suspicious python modules that can cause pip>=10 to crash.

        find /usr/lib{,64}/python*/site-packages -name '*.dist-info' -type f -print0 | xargs -0r rpm -qf | grep -v ' ' | tr '\n' '\0' | xargs -0r yum remove -y

        # ------------------------------------------------------------

        for attempt in $(seq $RPM_MAX_ATTEMPT -1 0); do
            $RPM_UPDATE --skip-broken && break
            echo "Retrying... $attempt chance(s) left."
            [ $attempt -gt 0 ] || exit 1
        done

        $IS_CONTAINER || sudo package-cleanup --oldkernels --count=3
        sudo yum autoremove -y

        # ------------------------------------------------------------

        "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" giampaolo/psutil,release- nicolargo/glances,v

        # ------------------------------------------------------------

        sudo updatedb
    )
    sudo rm -vf $STAGE/$i
    sync || true
done
