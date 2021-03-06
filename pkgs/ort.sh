# ================================================================
# Compile ONNXRuntime
# ================================================================

[ -e $STAGE/ort ] && ( set -xe
    cd $SCRATCH

    "$ROOT_DIR/pkgs/utils/pip_install_from_git.sh" cython/cython numpy/numpy,v

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" Microsoft/onnxruntime,v
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd onnxruntime

    git remote add patch https://github.com/xkszltl/onnxruntime.git

    PATCHES=""

    for i in $PATCHES; do
        git pull --no-edit --rebase patch "$i"
    done

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    (
        set -xe

        cd cmake/external

        # rm -rf googletest protobuf
        # cp -rf /usr/local/src/{gtest,protobuf} ./
        # mv gtest googletest

        for i in ./*.cmake; do
            sed -i "s/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR_GITHUB")\(\/..*\/.*\.git\)/$(sed 's/\([\/\.]\)/\\\1/g' <<< "$GIT_MIRROR")\1/" "$i"
        done
    )

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +xe
            . scl_source enable devtoolset-8
            set -xe
            export CC="gcc" CXX="g++"
            ;;
        'ubuntu')
            export CC="gcc-8" CXX="g++-8"
            ;;
        esac

        set +xe
        . "/opt/intel/mkl/bin/mklvars.sh" intel64
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        cmake                                               \
            -DCMAKE_BUILD_TYPE=Release                      \
            -DCMAKE_C_COMPILER="$CC"                        \
            -DCMAKE_CXX_COMPILER="$CXX"                     \
            -DCMAKE_{C,CXX,CUDA}_COMPILER_LAUNCHER=ccache   \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"           \
            -DCMAKE_POLICY_DEFAULT_CMP0003=NEW              \
            -DCMAKE_POLICY_DEFAULT_CMP0060=NEW              \
            -DCMAKE_VERBOSE_MAKEFILE=ON                     \
            -Deigen_SOURCE_PATH="/usr/local/include/eigen3" \
            -Donnxruntime_BUILD_FOR_NATIVE_MACHINE="$($TOOLCHAIN_CPU_NATIVE && echo 'ON' || echo 'OFF')"    \
            -Donnxruntime_BUILD_SHARED_LIB=ON               \
            -Donnxruntime_CUDNN_HOME='/usr/lib64'           \
            -Donnxruntime_ENABLE_PYTHON=ON                  \
            -Donnxruntime_ENABLE_LTO=OFF                    \
            -Donnxruntime_RUN_ONNX_TESTS=ON                 \
            -Donnxruntime_USE_BRAINSLICE=OFF                \
            -Donnxruntime_USE_CUDA=OFF                      \
            -Donnxruntime_USE_EIGEN_FOR_BLAS=OFF            \
            -Donnxruntime_USE_EIGEN_THREADPOOL=OFF          \
            -Donnxruntime_USE_FULL_PROTOBUF=ON              \
            -Donnxruntime_USE_JEMALLOC=OFF                  \
            -Donnxruntime_USE_LLVM=ON                       \
            -Donnxruntime_USE_MKLDNN=ON                     \
            -Donnxruntime_USE_MKLML=ON                      \
            -Donnxruntime_USE_NSYNC=OFF                     \
            -Donnxruntime_USE_NUPHAR=OFF                    \
            -Donnxruntime_USE_OPENBLAS=ON                   \
            -Donnxruntime_USE_OPENMP=ON                     \
            -Donnxruntime_USE_PREINSTALLED_EIGEN=OFF        \
            -Donnxruntime_USE_TENSORRT=OFF                  \
            -Donnxruntime_USE_TVM=OFF                       \
            -G"Ninja"                                       \
            ../cmake

        time cmake --build .
        time cmake --build . --target install

        if [ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ]; then
            curl -sSL 'https://repo.codingcafe.org/microsoft/onnxruntime/20181210.zip' > 'models.zip'
        else
            axel -n200 -o 'models.zip' 'https://onnxruntimetestdata.blob.core.windows.net/models/20181210.zip'
        fi

        md5sum -c <<< 'a966def7447f4ff04f5665bca235b3f3 models.zip'
        unzip -o models.zip -d ../models
        rm -rf models.zip

        time cmake --build . --target test || ! nvidia-smi

        python3 ../setup.py bdist_wheel
        pushd dist
        ../../rename_manylinux.sh
        sudo python3 -m pip install -IU ./*-manylinux1_*.whl
        popd

        # Exclude MKL-DNN/ONNX files.
        pushd "$INSTALL_ROOT"
        for i in mkl-dnn onnx; do
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
                [ "$(rpm -qa "roaster-$i")" ] || continue
                rpm -ql "roaster-$i" | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            'ubuntu')
                dpkg -l "roaster-$i" && dpkg -L "roaster-$i" | xargs -n1 | xargs -i -n1 find {} -maxdepth 0 -not -type d | sed -n 's/^\//\.\//p' | xargs rm -rf
                ;;
            esac
        done
 
        popd
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"
    
    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/onnxruntime
)
sudo rm -vf $STAGE/ort
sync || true
