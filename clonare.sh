#!/bin/bash

PS3="Alege o optiune din meniu " 
select ITEM in "Creaza un director de backup" "Renunta la operatiunea de clonare" 
do 
    case $REPLY in 
        1) read -p "Introduceti toata calea catre directorul de backup " backup_dir
           if [[ -d $backup_dir ]]
           then
               echo "Exista $backup_dir deja. Reia procesul!"
               exit 0
           else
               sudo mkdir -p $backup_dir
               break
           fi ;; 
        2) exit 0 ;;   
        *) echo "Optiune incorecta" 
    esac
done 

echo "Atentie!! Directorul in care se va face backup-ul este $backup_dir"
cd "$backup_dir"

###########################ATENTIE , TOT CE SE CREEAZA SE SALVEAZA IN NOUL DIRECTOR CREAT backup_dir ##################################

# Copiere utilizatori cu home_dir lor

user_file="user_details.txt"
shadow_file="shadow_details.txt"
group_file="group_details.txt"


echo "Copiere detalii despre utilizatori ..."
while read line
do
    user=$(echo $line | cut -f1 -d:)
    if [[ $user != "root" ]]
    then
        shell=$(echo $line | cut -f7 -d:)
        if [[ $shell == "/bin/bash" || $shell == "/bin/sh" ]]
        then
        
            pass_user=$(sudo egrep "^$user:" /etc/shadow)
            echo "$pass_user" >> $shadow_file
            id_gr_principal=$(echo $line | cut -f4 -d:)
            grup_principal=$(sudo egrep "$id_gr_principal" /etc/group)
            
            
            if [[ -n $grup_principal ]]
            then
            nume_grup=`cut -f1 -d: <<<$grup_principal`
            detalii_grup=`sudo egrep "$nume_grup" /etc/group`
            echo "$detalii_grup" >> $group_file
                line="$line"" ""grup_principal-""$grup_principal"
            fi
		grupuri_secundare="grupuri_secundare-"
            while read linie
            do
                verf=$(echo $linie | cut -f4 -d: | egrep "$user")
                if [[ -n $verf ]]
                then
                    nume_grup=`cut -f1 -d: <<<$linie`
                   grupuri_secundare="$grupuri_secundare""$nume_grup,"
                fi
            done < /etc/group
            line="$line"" ""$grupuri_secundare"
            echo "$line">>$user_file
        fi
    fi
done < /etc/passwd


# Crearea arhivei tar pentru utilizatori și grupuri
tar czf users_and_groups.tar.gz $user_file $shadow_file $group_file  2>/dev/null

old_ifs=$IFS
IFS=:

while read -r user pass uid gid gecos home shell
do
    if [[ -d $home ]]
    then
        echo "Copierea directorului home pentru $user..."
        tar czf "$user-home-$user.tar.gz" "$home" 2>/dev/null
    fi
done < user_details.txt

IFS=$old_ifs



# Copiere pachete instalate pe sistem

echo "Copiere pachete instalate ..."
dpkg-query -W -f='${binary:Package}\t${Version}\n' > installed_packages.txt
tar czf installed_packages.tar.gz installed_packages.txt  2>/dev/null

# Copiere fisiere de configurare de retea

echo "Copiere fisiere de configurare de retea ..."
network_config_archive="$backup_dir/network_config.tar.gz"
sudo tar czf "$network_config_archive" /etc/network /etc/netplan /etc/resolv.conf /etc/hosts /etc/nsswitch.conf /etc/hostname /etc/NetworkManager/system-connections 2>/dev/null

network_packages=("net-tools" "iproute2" "network-manager" "dhclient" "wpa_supplicant" "iptables")
for package in "${network_packages[@]}"
do
    if dpkg -s $package &> /dev/null
    then
        dpkg-query -W -f='${binary:Package}\t${Version}\n' $package >> network_packages.txt
    fi
done
tar czf network_packages.tar.gz network_packages.txt  2>/dev/null

# Copiere versiune kernel

echo "Copiere versiune de kernel ..."
uname -r > kernel_version.txt
tar czf kernel_version.tar.gz kernel_version.txt

# Copiere fisiere de configurare

echo "Copiere fisiere de configurare ..."
sudo tar czf system_backup.tar.gz --exclude="$backup_dir" --exclude="/dev" --exclude="/proc" --exclude="/sys" --exclude="/tmp" --exclude="/run" --exclude="/mnt" --exclude="/media" --exclude="/lost+found" / 2>/dev/null

echo "Terminare clonare si creare director de backup ..."

# Mutare arhive la destinatia finala

user="$1"
new_backup="/media/$user/1EF5-657F/"
find "$backup_dir" -type f -name "*.tar.gz" -exec mv {} "$new_backup" \; 2>/dev/null

nume_director=`basename $backup_dir`
echo "Backup-ul a fost mutat la $new_backup$nume_director"
exit 0