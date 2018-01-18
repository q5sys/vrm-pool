#!/bin/bash

BACKUP_DIR=/root/backups/
NAME=$(date | sed -e 's/ /./g')

# Make the directory just in case.
mkdir -p $BACKUP_DIR

# Create the backup.
tar -cpzf "${BACKUP_DIR}/backup.${name}.tar.gz" --exclude=/backup.tar.gz --one-file-system /
