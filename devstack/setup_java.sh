#!/bin/bash

ORACLE_JAVA_URL="http://download.oracle.com/otn-pub/java/jdk"
ORACLE_JAVA7_URL="${LAST_ORACLE_JAVA7_URL:-$ORACLE_JAVA_URL/7u80-b15/jdk-7u80}"
ORACLE_JAVA7_NAME="jdk1.7.0_80"
ORACLE_JAVA8_URL="${LAST_ORACLE_JAVA8_URL:-$ORACLE_JAVA_URL/8u66-b17/jdk-8u66}"
ORACLE_JAVA8_NAME="jdk1.8.0_66"


function setup_java {
    # Java version 8 is the last stable one
    local VERSION="${1:-8}"

    echo "Setup Java version: $VERSION"
    if test_java_version java "$VERSION"; then
        echo "Current Java version is already $VERSION."
    elif select_java "$VERSION"; then
        echo "Java version $VERSION has been selected."
    elif install_openjdk "$VERSION" && select_java "$VERSION"; then
        echo "OpenJDK version $VERSION has been installed and selected."
    elif install_other_java "$VERSION" && select_java "$VERSION"; then
        echo "Some Java version $VERSION has been installed and selected."
    else
        echo "ERROR: Unable to setup Java version $VERSION."
        return 1
    fi

    return 0
}

function setup_java_env() {
    local JAVA_COMMAND="${1:-java}"

    JAVA_LINK="$(which $JAVA_COMMAND)"
    if [[ "$JAVA_LINK" == "" ]]; then
        return 1
    fi

    export JAVA="$(readlink -f $JAVA_LINK)"
    export JAVA_HOME=$(echo $JAVA | sed "s:/bin/java::" | sed "s:/jre::")

    echo "JAVA is: $JAVA"
    echo "JAVA_HOME is: $JAVA_HOME"
    echo "Java version is:"
    $JAVA -version 2>&1

    return 0
}

function select_java {
    local VERSION="$1"
    local COMMAND

    for COMMAND in $(list_java_commands); do
        if test_java_version "$COMMAND" "$VERSION"; then
            if select_installed_java_command "$COMMAND"; then
                if test_java_version java "$VERSION"; then
                    return 0
                fi
            fi
        fi
    done

    return 1
}

function test_java_version {
    local COMMAND="$1"
    local VERSION="$2"

    $COMMAND -version 2>&1 | grep -q 'version "1\.'$VERSION'\..*"'
}

if is_ubuntu; then
    # --- Ubuntu -------------------------------------------------------------

    function list_java_commands {
        update-alternatives --list java
    }

    function select_installed_java_command {
        sudo update-alternatives --set java "$1"
    }

    function install_openjdk {
        local REQUIRED_VERSION="$1"
        apt_get install "openjdk-$REQUIRED_VERSION-jre-headless"
    }

    function install_other_java {
        local VERSION="$1"
        local PPA_REPOSITORY="ppa:webupd8team/java"
        local JAVA_INSTALLER="oracle-java${VERSION}-installer"
        local JAVA_SET_DEFAULT="oracle-java${VERSION}-set-default"

        # Accept installer license
        echo "$JAVA_INSTALLER" shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections

        # Remove all existing set-default versions
        apt_get remove oracle-java*-set-default
        if apt_get install $JAVA_INSTALLER ; then
            if apt_get install $JAVA_SET_DEFAULT ; then
                return 0  # Some PPA was already providing desired packages
            fi
        fi

        # Add PPA only when package is not available
        if apt_get install software-properties-common; then
            # I pipe this after echo to emulate an user key-press
            if echo | sudo add-apt-repository "$PPA_REPOSITORY"; then
                if apt_get update; then
                    if apt_get install $JAVA_INSTALLER ; then
                        if apt_get install $JAVA_SET_DEFAULT ; then
                            return 0
                        fi
                    fi
                fi
            fi
        fi

        # Something has gone wrong!
        return 1
    }

else
    # --- Red Hat -------------------------------------------------------------

    function list_java_commands {
         alternatives --display java 2>&1 | grep -v '^[[:space:]]' | awk '/[[:space:]]- priority[[:space:]]/{print $1}'
    }

    function install_openjdk {
        local VERSION="$1"
        # Can't use yum_install because it would exit in case of failure
        sudo yum install -y java-1.$VERSION.*-openjdk-headless
    }

    function install_other_java {
        local VERSION="$1"

        if [[ "$(uname -m)" == "x86_64" ]]; then
            local ARCH=linux-x64
        else
            local ARCH=linux-i586
        fi

        if [[ "$VERSION" == 7 ]]; then
            ORIGIN=$ORACLE_JAVA7_URL
            TARGET=$ORACLE_JAVA7_NAME
        elif [[ "$VERSION" == 8 ]]; then
            ORIGIN=$ORACLE_JAVA8_URL
            TARGET=$ORACLE_JAVA8_NAME
        else
            echo "Unsupported Java version: $VERSION."
            return 1
        fi

        local NEW_JAVA="/usr/java/$TARGET/jre/bin/java"
        if test_java_version "$NEW_JAVA" "$VERSION"; then
            if sudo alternatives --install /usr/bin/java java "$NEW_JAVA" 200000; then
                return 0
            fi
        fi

        local EXT
        local WGET_OPTIONS="-c --no-check-certificate --no-cookies"
        local HEADER="Cookie: oraclelicense=accept-securebackup-cookie"

        for EXT in "rpm" "tar.gz"; do
            local URL="$ORIGIN-$ARCH.$EXT"
            local PACKAGE="/tmp/$(basename $URL)"

            if wget $WGET_OPTIONS --header "$HEADER" "$URL" -O "$PACKAGE"; then
                case "$EXT" in
                    "rpm")
                        sudo rpm -i "$PACKAGE"
                        ;;
                    "tar.gz")
                        sudo mkdir -p /usr/java && sudo tar -C /usr/java -xzf "$PACKAGE"
                        ;;
                    *)
                        echo "Unsupported extension: $EXT"
                        ;;
                esac

                if test_java_version "$NEW_JAVA" "$VERSION"; then
                    if sudo alternatives --install /usr/bin/java java "$NEW_JAVA" 200000; then
                        return 0
                    fi
                fi

                echo "Unable to register installed java."

            else
                echo "Unable to download java archive: $URL"
            fi

        done

        return 1
    }

    function select_installed_java_command {
        sudo alternatives --set java "$1"
    }
fi
