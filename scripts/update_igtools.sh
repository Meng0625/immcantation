#!/bin/bash
# Script to update presto, changeo, alakazam, shm and tigger
# 
# Author:  Jason Anthony Vander Heiden, Mohamed Uduman
# Date:    2015.02.18
# 
# Arguments:
#   -u = Bitbucket username. If not specified, username will be prompted.
#   -p = Bitbucket password. If not specified, password will be prompted.
#   -t = Target folder for install of presto and changeo.
#   -x = If specified, install the alakazam-topology and alakazam-repertoire
#        prototype packages.
#   -h = Display help.
#
# Creates Directories:
#   ~/tmp
#   ~/apps/presto
#   ~/apps/changeo

# Set default parameters
set -e
PROTOTYPES=false
PASSWORD_PROMPT=true
USERNAME_PROMPT=true
TARGET_DIR=$HOME/apps

# Print usage
usage () {
    echo "Usage: `basename $0` [OPTIONS]"
    echo "  -u  Bitbucket username."
    echo "  -p  Bitbucket password."
    echo "  -t  Target location for install of presto and changeo. Default: ~/apps."
    echo "  -x  Install prototype packages."
    echo "  -h  This message."
}

# Get commandline arguments
while getopts "u:p:t:xh" OPT; do
    case "$OPT" in
    u)  USERNAME=$OPTARG
        USERNAME_PROMPT=false
        ;;
    p)  PASSWORD=$OPTARG
        PASSWORD_PROMPT=false
        ;;
    t)  TARGET_DIR=$OPTARG
        ;;
    x)  PROTOTYPES=true
        ;;
    h)  usage
        exit
        ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    :)  echo "Option -$OPTARG requires an argument" >&2
        exit 1
        ;;
    esac
done

# Ask for username if not provided
if $USERNAME_PROMPT; then
    read -p "Username: " USERNAME
fi

# Ask for password if not provided
if $PASSWORD_PROMPT; then
    read -s -p "Password: " PASSWORD
fi


# Create directories
mkdir -p $HOME/tmp; mkdir -p $TARGET_DIR/presto; mkdir -p $TARGET_DIR/changeo

# Download bits
echo -e "Downloading tip from repos..."
curl -# -u "${USERNAME}:${PASSWORD}" \
    https://bitbucket.org/javh/presto/get/tip.tar.gz -o $HOME/tmp/presto.tar.gz
curl -# -u "${USERNAME}:${PASSWORD}" \
    https://bitbucket.org/javh/changeo/get/tip.tar.gz -o $HOME/tmp/changeo.tar.gz
curl -# -u "${USERNAME}:${PASSWORD}" \
    https://bitbucket.org/javh/alakazam/get/tip.tar.gz -o $HOME/tmp/alakazam.tar.gz
curl -# -u "${USERNAME}:${PASSWORD}" \
    https://bitbucket.org/uduman/shm/get/tip.tar.gz -o $HOME/tmp/shm.tar.gz
curl -# -u "${USERNAME}:${PASSWORD}" \
    https://bitbucket.org/dgadala/tigger/get/tip.tar.gz -o $HOME/tmp/tigger.tar.gz

if $PROTOTYPES; then
    curl -# -u "${USERNAME}:${PASSWORD}" \
        https://bitbucket.org/javh/prototype-prestor/get/tip.tar.gz \
        -o $HOME/tmp/prototype-prestor.tar.gz
    curl -# -u "${USERNAME}:${PASSWORD}" \
        https://bitbucket.org/javh/prototype-repertoire/get/tip.tar.gz \
        -o $HOME/tmp/prototype-repertoire.tar.gz
    curl -# -u "${USERNAME}:${PASSWORD}" \
        https://bitbucket.org/javh/prototype-topology/get/tip.tar.gz \
        -o $HOME/tmp/prototype-topology.tar.gz
fi


# Install python tools
echo -e "Installing presto..."
tar -zxf $HOME/tmp/presto.tar.gz --wildcards --exclude="tests" --strip-components=1 \
    -C $TARGET_DIR/presto \*.py

echo -e "Installing changeo..."
tar -zxf $HOME/tmp/changeo.tar.gz --wildcards --exclude="tests" --strip-components=1 \
    -C $TARGET_DIR/changeo \*.py \*/models

# Install R packages
RSCRIPT="options(repos=c(CRAN=\"http://cran.rstudio.com\")); \
         library(roxygen2); library(devtools); \
         document(\"${HOME}/tmp/package_directory\"); \
         install_deps(\"${HOME}/tmp/package_directory\"); \
         build(\"${HOME}/tmp/package_directory\", vignettes=FALSE); \
         install(\"${HOME}/tmp/package_directory\")"

echo -e "Installing alakazam..."
mkdir -p $HOME/tmp/alakazam
tar -zxf $HOME/tmp/alakazam.tar.gz --wildcards --exclude="tests" --strip-components=1 \
    -C $HOME/tmp/alakazam
Rscript -e "${RSCRIPT//package_directory/alakazam}"

echo -e "Installing shm..."
mkdir -p $HOME/tmp/shm
tar -zxf $HOME/tmp/shm.tar.gz --wildcards --exclude="tests" --strip-components=1 \
    -C $HOME/tmp/shm
Rscript -e "${RSCRIPT//package_directory/shm}"

echo -e "Installing tigger..."
mkdir -p $HOME/tmp/tigger
tar -zxf $HOME/tmp/tigger.tar.gz --wildcards --exclude="tests" --strip-components=1 \
    -C $HOME/tmp/tigger
Rscript -e "${RSCRIPT//package_directory/tigger}"


# Install prototype R packages
if $PROTOTYPES; then
    echo -e "Installing prototype-prestor..."
    mkdir -p $HOME/tmp/prototype-prestor
    tar -zxf $HOME/tmp/prototype-prestor.tar.gz --wildcards --exclude="tests" \
        --strip-components=1 -C $HOME/tmp/prototype-prestor
    Rscript -e "${RSCRIPT//package_directory/prototype-prestor}"

    echo -e "Installing prototype-repertoire..."
    mkdir -p $HOME/tmp/prototype-repertoire
    tar -zxf $HOME/tmp/prototype-repertoire.tar.gz --wildcards --exclude="tests" \
        --strip-components=1 -C $HOME/tmp/prototype-repertoire
    Rscript -e "${RSCRIPT//package_directory/prototype-repertoire}"

    echo -e "Installing prototype-topology..."
    mkdir -p $HOME/tmp/prototype-topology
    tar -zxf $HOME/tmp/prototype-topology.tar.gz --wildcards --exclude="tests" \
        --strip-components=1 -C $HOME/tmp/prototype-topology
    Rscript -e "${RSCRIPT//package_directory/prototype-topology}"
fi
