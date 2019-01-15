#!/usr/bin/env bash

if [ -d "./BookHTML" ] && [ "$1" == "--force" ]
then
	echo "Removing the old files."
	rm -rf ./BookHTML/
fi

sphinx-build -b html -d BookHTML/doctrees Book BookHTML/html
