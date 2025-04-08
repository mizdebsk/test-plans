#!/bin/sh
set -eu

# Components with tests in a dedicated dist-git repository in "tests"
# namespace, eg. https://src.fedoraproject.org/tests/maven
external="ant maven javapackages-tools"

# Components with that have tests stored directly in their "rpms"
# dist-git repository, eg. https://src.fedoraproject.org/rpms/maven
internal="byaccj javacc jctools jflex maven-surefire modello jakarta-activation jaxb-api jaxb-dtd-parser jaxb-fi jaxb-istack-commons jaxb-stax-ex jaxb bcel"

external_url_template="https://gitlab.com/redhat/centos-stream/tests/@{id}.git"
#external_url_template="/home/kojan/git/@{id}-tests"
internal_url_template="https://src.fedoraproject.org/rpms/@{cmp}.git"
#internal_url_template="/home/kojan/tmp/fp/@{cmp}"

# Test matrix. Columns are:
# tmt tag
# |    jdk version short
# |    |   jdk version long
# |    |   |      jdk headless
# |    |   |      |
matrix="sysjdk 21 21 false
unbound
jdk21  21  21     false
jre21  21  21     true
jdk25  25  25     false
jre25  25  25     true"


while read tag jdk_version_short jdk_version_full jdk_headless; do

    exec >${tag}.fmf

    suffix="${tag}"

    echo "environment:"
    echo "  MAVEN_IT_GIT_REF: maven-3.9.x"
    if [[ "${tag}" != "unbound" ]]; then
        suffix="openjdk${jdk_version_short}"
        echo "  OPENJDK_VERSION: ${jdk_version_full}"
        echo "  OPENJDK_HEADLESS: \"${jdk_headless}\""
    fi

    if [[ "${tag}" != "sysjdk" ]]; then
        echo "prepare:"
        echo "  - name: mbici-install"
        echo "    how: install"
        echo "    package:"
        echo "     - ant-${suffix}"
        echo "     - maven-${suffix}"
        if [[ "${tag}" = "unbound" ]]; then
                echo "  - name: mbici-jlink"
                echo "    how: shell"
                echo "    script: |"
                echo "      test -d /opt/java && test -x /usr/local/bin/java && exit 0"
                echo "      dnf -y install java-21-openjdk-jmods"
                echo "      jlink --add-modules java.base,java.logging,java.xml,java.naming --output /opt/java"
                echo "      ln -s /opt/java/bin/java /usr/local/bin/java"
                echo "      dnf -y remove java-21-openjdk-jmods"
        else
            if ${jdk_headless}; then
                echo "  - name: mbici-erase"
                echo "    how: shell"
                echo "    script: dnf -y remove java-*-openjdk"
            fi
        fi
        echo "tag:"
        echo "  - matrix"
    fi

    echo "discover:"

    if [[ "${tag}" = "sysjdk" ]]; then
        for cmp in ${internal}; do
            url=$(sed "s/@{cmp}/${cmp}/g" <<<"${internal_url_template}")
            echo "  - name: ${cmp}"
            echo "    how: fmf"
            echo "    url: ${url}"
            if [[ "${tag}" != "sysjdk" ]]; then
                echo "    filter: tag:${tag}"
            fi
        done
    fi

    for id in ${external}; do
        url=$(sed "s/@{id}/${id}/g" <<<"${external_url_template}")
        echo "  - name: tests/${id}"
        echo "    how: fmf"
        echo "    url: ${url}"
        if [[ "${tag}" != "sysjdk" ]]; then
            echo "    filter: tag:${tag}"
        fi
    done

    echo "execute:"
    echo "  how: tmt"

done <<<"${matrix}"
