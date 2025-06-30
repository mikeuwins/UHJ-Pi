#!/bin/bash

echo "Cleaning previous builds..."
rm -f phono-control

echo "Building phono-control..."
gcc -o phono-control phono-control-copilot-simplify.c -lhidapi-hidraw

if [ $? -eq 0 ]; then
    echo "Build successful."
    echo "Installing to /usr/local/bin..."
    sudo cp phono-control /usr/local/bin/phono-control

    if [ $? -eq 0 ]; then
        echo "Installation successful: /usr/local/bin/phono-control has been updated."
    else
        echo "Installation failed: Could not copy file."
    fi
else
    echo "Build failed. Please check for errors."
fi

