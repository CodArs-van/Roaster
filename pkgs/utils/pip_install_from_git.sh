#!/bin/bash

set -e

if [ ! "$ROOT_DIR" ]; then
    echo '$ROOT_DIR is not defined.'
    echo 'Running in standalone mode.'
    export ROOT_DIR="$(readlink -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(readlink -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
fi

CACHE_VALID=false

for i in pypa/setuptools,v pypa/{pip,wheel} PythonCharmers/python-future,v $@; do
    PKG_PATH="$(cut -d, -f1 <<< "$i,")"
    if grep '^[[:alnum:]]' <<< "$PKG_PATH" > /dev/null; then
        . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
        URL="git+$GIT_REPO@$GIT_TAG"
    else
        URL="$(readlink -e $PKG_PATH)"
        [ -d "$URL" ]
        USE_LOCAL_GIT=true
    fi

    PKG="$(basename "$PKG_PATH")"
    if [ "_$PKG" = "_python-future" ]; then
        PKG="future"
    fi

    if grep '/setuptools' <<< "/$i" > /dev/null; then
        echo "Cannot build $PKG from source. Install it from wheel instead."
        URL="$PKG"
    fi
    if grep '/protobuf' <<< "/$i" > /dev/null; then
        echo "Cannot build $PKG from source. Install it from wheel instead."
        URL="$PKG"
    fi
    for py in ,python3 rh-python36,python; do
    (
        py="$py,"

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +e
            . scl_source enable "$(cut -d',' -f1 <<< "$py")"
            set -e
            ;;
        'ubuntu')
            # Skip SCL Python.
            [ "$(cut -d',' -f1 <<< "$py")" ] && exit 0 
            export CC="$(which gcc-8)" CXX="$(which g++-8)"
            ;;
        esac

        py="$(which "$(cut -d',' -f2 <<< "$py")")"
        # Not exactly correct since the actual package name is defined by "setup.py".
        until $CACHE_VALID; do
            CACHED_LIST="$("$py" -m pip freeze --all | tr '[:upper:]' '[:lower:]')"
            CACHE_VALID=true

            # Always remove enum34.
            if [ "$(grep '^enum34==' <<< "$CACHED_LIST")" ]; then
                sudo "$py" -m pip uninstall -y 'enum34'
                CACHE_VALID=false
                continue
            fi
        done
        if [ ! "$USE_LOCAL_GIT" ] && [ "$GIT_TAG_VER" ] && [ "_$(sed -n "s/^$(tr '[:upper:]' '[:lower:]' <<< "$PKG")==//p" <<< "$CACHED_LIST")" = "_$GIT_TAG_VER" ]; then
            echo "Package \"$PKG\" for \"$py\" is already up-to-date ($GIT_TAG_VER). Skip."
            continue
        fi
        sudo "$py" -m pip install -U "$URL" || sudo "$py" -m pip install -IU "$URL"
        CACHE_VALID=false
    )
    done
done
