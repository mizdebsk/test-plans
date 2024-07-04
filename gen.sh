#!/bin/sh
set -eu

# Components with tests in a dedicated dist-git repository in "tests"
# namespace, eg. https://src.fedoraproject.org/tests/maven
external="ant maven"

# Components with that have tests stored directly in their "rpms"
# dist-git repository, eg. https://src.fedoraproject.org/rpms/maven
internal="ant maven byaccj javacc jctools jflex maven-surefire modello jakarta-activation jaxb-api jaxb-dtd-parser jaxb-fi jaxb-istack-commons jaxb-stax-ex jaxb bcel"

external_url_template="https://src.fedoraproject.org/tests/@{id}.git"
#external_url_template="/home/kojan/git/@{id}-tests"
internal_url_template="https://src.fedoraproject.org/rpms/@{cmp}.git"
#internal_url_template="/home/kojan/tmp/fp/@{cmp}"

# Test matrix. Columns are:
# tmt tag
# |    jdk version short
# |    |   jdk version long
# |    |   |      jdk headless
# |    |   |      |
matrix="sysjdk
jdk8   8   1.8.0  false
jre8   8   1.8.0  true
jdk11  11  11     false
jre11  11  11     true
jdk17  17  17     false
jre17  17  17     true
jdk21  21  21     false
jre21  21  21     true"


while read tag jdk_version_short jdk_version_full jdk_headless; do

    exec >${tag}.fmf

    if [[ "${tag}" != "sysjdk" ]]; then
	echo "environment:"
	echo "  OPENJDK_VERSION: ${jdk_version_full}"
	echo "  OPENJDK_HEADLESS: \"${jdk_headless}\""
	echo "prepare:"
	echo "  - name: mbici-install"
	echo "    how: install"
	echo "    package:"
	echo "     - maven-openjdk${jdk_version_short}"
	if ${jdk_headless}; then
	    echo "  - name: mbici-erase"
	    echo "    how: shell"
	    echo "    script: dnf -y remove java-*-openjdk"
	fi
	echo "tag:"
	echo "  - matrix"
    fi

    echo "discover:"

    for cmp in ${internal}; do
	url=$(sed "s/@{cmp}/${cmp}/g" <<<"${internal_url_template}")
	echo "  - name: ${cmp}"
	echo "    how: fmf"
	echo "    url: ${url}"
	if [[ "${tag}" != "sysjdk" ]]; then
	    echo "    filter: tag:${tag}"
	fi
    done

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
