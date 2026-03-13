#!/bin/bash

if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "OS detect nahi hua."
    exit 1
fi

case "$ID" in
    ubuntu)
        bash ubuntu
        ;;
    debian)
        bash debian
        ;;
    *)
        echo "Sirf Ubuntu ya Debian supported hai."
        exit 1
        ;;
esac
