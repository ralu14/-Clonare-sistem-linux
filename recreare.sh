#!/bin/bash

user_file="user_details.txt"
shadow_file="shadow_details.txt"

# Verificăm dacă fișierele de intrare există

if [[ ! -f $user_file || ! -f $shadow_file ]]; then
    echo "Fișierele $user_file și $shadow_file trebuie să existe în directorul curent."
    exit 1
fi

# Creăm utilizatorii și configurăm parolele lor
while IFS=: read -r user pass uid gid gecos home shell
do
    sudo useradd -m -u $uid -g $gid -c "$gecos" -s $shell $user
    sudo usermod -p $(egrep "^$user:" $shadow_file | cut -d: -f2) $user
done < $user_file

echo "Utilizatorii au fost creați cu succes pe noul sistem."


backup_home="/media/backup_home"

# Asigură-te că backup_home este montat și disponibil

old_ifs=$IFS
IFS=:

while read -r user pass uid gid gecos home shell
do
    if [[ -d $backup_home/$(basename $home) ]]
    then
        echo "Restaurarea directorului home pentru $user..."
        sudo rsync -a "$backup_home/$(basename $home)/" "$home/"
        sudo chown -R $user:$gid "$home"
    fi
done < $user_file

IFS=$old_ifs

echo "Restaurarea directoarelor home a fost completă."
