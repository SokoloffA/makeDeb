#!/bin/bash

# BEGIN_COMMON_COPYRIGHT_HEADER
# (c)LGPL2+
#
#
# Copyright: 2014 Alexander Sokoloff
# Authors:
#   Alexander Sokoloff <sokoloff.a@gmail.com>
#
# This program or library is free software; you can redistribute it
# and/or modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.

# You should have received a copy of the GNU Lesser General
# Public License along with this library; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA
#
# END_COMMON_COPYRIGHT_HEADER 
 
SCRIPT_VERSION="0.1.0"

function version {
    echo "makeDeb $SCRIPT_VERSION"
    exit
}

function help {
  cat << HELP_TEXT
Usage: makeDeb.sh [options] <path-to-source-tar-file> <debian-directory>

Options
  -h|--help             display this message
  -o|--outdirt=DIR      write result to DIR, home directory by default
  -r|--release=RELEASE  release name (sid, squeeze, testing, maveric, natty etc.), autodetect if ommited
  -d|--distrib=DISTRIB  distib type (Debian or Ubuntu), autodetect if ommited
  --ver=VERSION         package version
  -S|--sign             sign a result files
  -s|--source           build a source package, if omitted build a binary package
  --debug               debug mode, not build package - only create debian directory
  -V|--version          Print program version
HELP_TEXT
}



VARIABLES=""

function debug
{
    [ -n "$DEBUG" ] && echo $@ >&2
}

function setVariable
{
    shift
    local VAR=$1
    shift

    VARIABLES="${VARIABLES}${VAR}=$*\n"
    debug "set variable: ${VAR} = $*"
    #debug "variables $VARIABLES"
}

function getVariable
{
    printf "$VARIABLES" | awk -F'=' "/${1}=/ {print(\$2)}"
}

function clearVariables
{
    debug "clear variables: $VARIABLES"
    VARIABLES=''
}

function checkIf
{
    shift
    local name=$1
    shift

    case $name in
        DISTRIB)
            val=`echo $DISTRIB | awk '{print $1 }' | tr '[:lower:]' '[:upper:]'`;
            local caseInsensitive=1;
            ;;

        RELEASE)
            val=`echo $RELEASE | awk '{print $1 }' | tr '[:lower:]' '[:upper:]'`;
            local caseInsensitive=1;
            ;;

        *)
            val=`getVariable ${name}`
            ;;
    esac

    for i in $@ ; do
        local a=$i
        [ "$caseInsensitive" ] && a=`echo $i | awk '{print $1 }' | tr '[:lower:]' '[:upper:]'`
        if [ "$a" = "$val" ]; then
            echo 1
            return 1
        fi
    done

    echo 0
}


token=''
line=''
function nextToken
{
    while  IFS='' read -r "line"; do
        token=`echo $line | awk '{print $1 }' | tr '[:lower:]' '[:upper:]'`
        case $token in
            %IF|%IFNOT|%ELSIF|%ELSEIF|%ELSE|%ENDIF|%SET)
                return 0
                ;;

            *)
                echo "$line" | sed            \
                    -e"s/%NAME%/${NAME}/g"    \
                    -e"s/%VERSION%/${VER}/g"  \
                    -e"s/%RELEASE%/${RELEASE}/g" \
                    -e"s/%DISTRIB%/${DISTRIB}/g" \
                    -e"s/%DATE%/${DATE}/g" \
                    -e"s/%DEBEMAIL%/${DEBEMAIL}/g" \
                    -e"s/%DEBFULLNAME%/${DEBFULLNAME}/g"
        esac
    done

    token=''
    return
}



function skipBlock
{
    local level=0
    while  IFS='' read -r "line"; do
        token=`echo $line | awk '{print $1 }' | tr '[:lower:]' '[:upper:]'`
        case $token in
            %IF|%IFNOT)
                let 'level++'
                ;;

            %ENDIF)
                [ $level = "0" ] && break
                let 'level--'
                ;;

            %ELSIF|%ELSEIF|%ELSE)
                [ $level = "0" ] && break
                ;;

            *)
                ;;
        esac
    done
}


function processBlock
{
    nextToken

    while [ "$token" != "" ]; do
        case $token in
            %IF|%IFNOT)
                local skip=
                while [ "$token" != "" ] && [ $token != "%ENDIF" ]; do
                    case $token in
                        %IF|%ELSIF|%ELSEIF)
                            check=$(checkIf $line)
                            ;;

                        %IFNOT)
                            check=$(checkIf $line)
                            check=$(( ! $check ))
                            ;;

                        %ELSE)
                            check=1
                            ;;
                    esac

                    if [ "$skip" != "1" ] && [ "$check" = "1" ]; then
                        processBlock
                        skip=1
                    else
                        skipBlock
                    fi
                done
                ;;

            %SET)
                setVariable $line
                ;;

            %ELSIF|%ELSEIF|%ELSE|%ENDIF)
                break
                ;;

            *)
                echo "Unexpected token '$line'" >&2
                exit 3
                ;;
        esac
        nextToken
    done
}

function prepareFile
{
    processBlock < $1
}


TYPE='-b'
SIGN='-uc -us'
ARG1=""
ARG2=""

while [ $# -gt 0 ]; do
  case $1 in
    -h|--help)
        help
        exit
      ;;
    -V|--version)
        version
        exit
      ;;  
    -o|--outdir)
        OUT_DIR=$2;
        shift 2
      ;;

    -r|--release)
        RELEASE=$2
        shift 2
      ;;

    -d|--distrib)
        DISTRIB=$2
        shift 2
      ;;

    --ver)
        VER=$2
        shift 2
      ;;

    -s|--source)
        TYPE='-S'
        shift
      ;;

    -S|--sign)
        SIGN=''
        shift
      ;;

    --debug)
        DEBUG=1
        shift
      ;;

    --)
        shift
        break
      ;;

    *)
        ARG1=${ARG2}
        ARG2=$1
        shift
      ;;

  esac
done

if [ -f "${ARG1}" ]; then SRC=${ARG1}; fi
if [ -f "${ARG2}" ]; then SRC=${ARG2}; fi
if [ -d "${ARG1}" ]; then DEB_DIR=${ARG1}; fi
if [ -d "${ARG2}" ]; then DEB_DIR=${ARG2}; fi


if [ -z "${SRC}" ]; then
    echo "missing path-to-source operand" >&2
    help
    exit 2
fi

if [ -z "${DEB_DIR}" ]; then
    echo "missing path to debian directory option" >&2
    help
    exit 2
fi

SRC=`readlink -m ${SRC}`

if [ -z "${RELEASE}" ]; then
    RELEASE=`awk -F"=" '/DISTRIB_CODENAME=/ {print($2)}' /etc/lsb?release`
fi

if [ -z "${RELEASE}" ]; then
    echo "missing release option"
    help
    exit 2
fi


if [ -z "${DISTRIB}" ]; then
    DISTRIB=`awk -F"=" '/DISTRIB_ID=/ {print($2)}' /etc/lsb?release`
fi

if [ -z "${DISTRIB}" ]; then
    echo "missing distrib option"
    help
    exit 2
fi

NAME=$(basename "${SRC}" | awk -F '[-]' '{print($1)}')

if [ -z "$VER" ]; then
    MAJOR_VER=$(echo "${SRC}" | awk -F '[-_]' '{print($2)}' | awk -F '.' '{print($1)}')
    MINOR_VER=$(echo "${SRC}" | awk -F '[-_]' '{print($2)}' | awk -F '.' '{print($2)}')
    PATCH_VER=$(echo "${SRC}" | awk -F '[-_]' '{print($2)}' | awk -F '.' '{print($3)}')

    VER="${MAJOR_VER}.${MINOR_VER}.${PATCH_VER}"
fi

if [ -z "$OUT_DIR" ]; then
    OUT_DIR="${HOME}/${NAME}_${VER}_deb"
fi

if [ -z "$DEBEMAIL" ]; then
  DEBEMAIL=${EMAIL}
fi

if [ -n "$DEBUG" ]; then
  TYPE="Debug"
fi

echo "*******************************"
echo " Source:     ${SRC}"
echo " Debian dir: ${DEB_DIR}"
echo ""
echo " Name:    ${NAME}"
echo " Ver:     ${VER}"
[ "${TYPE}" = "-b"    ] && echo " Type:    binary"
[ "${TYPE}" = "-S"    ] && echo " Type:    source"
[ "${TYPE}" = "Debug" ] && echo " Type:    debug"
echo " Distrib: ${DISTRIB}"
echo " Release: ${RELEASE}"
echo " Out dir: ${OUT_DIR}"

echo "*******************************"


OUT_DIR=`readlink -m ${OUT_DIR}`
mkdir -p ${OUT_DIR} || exit 2

DIR=${OUT_DIR}/${NAME}-${VER}
rm -rf ${DIR}


if [ -z "$DEBUG" ]; then
    cp "${SRC}" ${OUT_DIR}/${NAME}_${VER}.orig.tar.bz2
    cd ${OUT_DIR} && tar xvf ${NAME}_${VER}.orig.tar.bz2 ${NAME}-${VER}
fi


for RELEASE in ${RELEASE}; do
    # Debin directory .....................
    rm -r ${DIR}/debian 2>/dev/null
    mkdir -p ${DIR}/debian
    mkdir -p ${DIR}/debian/source
    DATE=`date -R`

    clearVariables
    prepareFile ${DEB_DIR}/control > ${DIR}/debian/control

    for src in `find ${DEB_DIR} -type f \! -name "control"`; do
        dest=$(echo $src | sed -e"s|${DEB_DIR}|${DIR}/debian|")
        prepareFile "${src}" > ${dest}
        chmod --reference "${src}" ${dest}
    done
    # Debin directory .....................

    if [ -z "$DEBUG" ]; then
      cd ${DIR} && debuild ${TYPE} ${SIGN} -rfakeroot
      ret=$?
      [ $ret -eq 0 ] || exit $ret
    else
      mv ${DIR}/debian ${DIR}/${RELEASE}-debian
    fi
done

if [ "${TYPE}" = '-b' ]; then
    echo "................................."
    echo "Check files:"
    PKGS=`awk '/Package:/ {print $2}' ${DIR}/debian/control`

    for file in `find ${DIR}/debian/tmp \( -type f -o -type l \) 2>/dev/null`; do
        file=`echo $file | sed -e"s|${DIR}/debian/tmp||"`
        #echo $file
        pkgNames=''
        let 'pkgCount=0'

        for pkg in ${PKGS}; do
            if [ `ls "${DIR}/debian/${pkg}$file" 2>/dev/null` ]; then
                let 'pkgCount++'
                pkgNames="${pkgNames}\n\t${pkg}"
            fi
        done

        if [ $pkgCount -eq 0 ]; then
            echo -e "Missing file: ${file}";

        elif [ $pkgCount -gt 1 ]; then
            echo -e "Duplicates:  ${file}$pkgNames"
        fi

    done
fi

