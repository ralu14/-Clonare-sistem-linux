#!/bin/bash

if [[ $# -eq 0 ]]
then
    echo "Trebuie sa introduceti si calea absoluta a directorului de backup pe care doriti sa-l reconstruiti pe sistemul dvs."
    exit 0
else
    backup_dir="$1"
fi

cd $backup_dir

# Restaurare versiune kernel
kernel_version_file="$backup_dir/kernel_version.txt"
tar xzf "$backup_dir/kernel_version.tar.gz" -C "$backup_dir" --no-same-owner

# Comparam versiunea de kernel si facem upgrade daca este necesar

echo "Compararea versiunii de kernel..."
current_kernel_version=$(uname -r)
backup_kernel_version=$(cat "$kernel_version_file")

if [ "$current_kernel_version" != "$backup_kernel_version" ]; then
    echo "Versiunea de kernel difera. Se va face schimbarea de la $current_kernel_version la $backup_kernel_version."
    
    current_major_version=$(echo $current_kernel_version | cut -d'-' -f1)
    backup_major_version=$(echo $backup_kernel_version | cut -d'-' -f1)
    
    if [ "$current_major_version" -gt "$backup_major_version" ]; then
        echo "Kernel-ul curent este mai nou. Se va face downgrade."
    else
        echo "Kernel-ul curent este mai vechi. Se va face upgrade."
    fi

    sudo apt-get update
    sudo apt-get install -y linux-image-$backup_kernel_version linux-headers-$backup_kernel_version
    sudo update-grub
    echo "Kernel-ul a fost actualizat. Sistemul va fi restartat pentru a încărca noul kernel."
    sudo reboot
else
    echo "Kernel-ul este deja la versiunea specificată: $current_kernel_version."
fi

echo "Restaurarea sistemului a fost completă."


system_backup_archive="$backup_dir/system_backup.tar.gz"

# Restauram sistemul de fisiere din arhiva

echo "Restaurarea sistemului de fisiere..."
sudo tar xzf "$system_backup_archive" -C / 2>/dev/null
echo "Restaurarea sistemului de fisiere este completa."


# Restauram configurarile de retea
network_config_archive="$backup_dir/network_config.tar.gz"
network_packages_file="$backup_dir/network_packages.txt"

sudo tar xzf "$network_config_archive" -C / 2>/dev/null

echo "Configurarile de retea au fost restaurate."

# Instalam pachetele de retea specifice din network_packages.txt
tar xzf "$backup_dir/network_packages.tar.gz" -C "$backup_dir" --no-same-owner

while IFS=$'\t' read -r package version
do
    echo "Instalare pachet de retea $package versiunea $version"
    sudo apt-get install -y "$package=$version"
done < "$network_packages_file"

echo "Pachetele de retea au fost instalate."

# Instalam pachetele de sistem din installed_packages.txt
installed_packages_file="$backup_dir/installed_packages.txt"
failed_packages_file="$backup_dir/failed_packages.txt"

install_package() {
    local package=$1
    local version=$2

    echo "Instalare $package versiunea $version"
    if [[ ! sudo apt-get install -y "$package=$version" ]]
    then
        echo "$package $version" >> "$failed_packages_file"
    fi
}

# instalam pachetele din fisierul installed_packeges.txt
while IFS=$'\t' read -r package version
 do
    install_package "$package" "$version"
done < "$installed_packages_file"

if [[ -s "$failed_packages_file" ]]
 then
    echo "Urmatoarele pachete nu au putut fi instalate nici dupa reincercare:"
    cat "$failed_packages_file"
else
    echo "Toate pachetele de sistem au fost reinstalate cu versiunile specifice."
fi


# Cream utilizatorii, grupurile si configuram parolele lor
echo "Restaurare utilizatori și grupuri..."
tar xzf "$backup_dir/users_and_groups.tar.gz" -C "$backup_dir" --no-same-owner

user_file="$backup_dir/user_details.txt"
shadow_file="$backup_dir/shadow_details.txt"
group_file="$backup_dir/group_details.txt"

# Verificam daca fisierele de intrare exista
if [[ ! -f $user_file || ! -f $shadow_file || ! -f $group_file ]]
then
    echo "Fisierele necesare trebuie sa existe in directorul de backup."
    exit 1
else
	echo "fisierele exista"
fi

while read line
do
    nume_grup=$(echo $line | cut -f1 -d:)
    verf=$(egrep "^$nume_grup" /etc/group)
    if [[ -n $verf ]] 
    then
        echo "Exista deja grupul $nume_grup"
    else    
        echo "Se creeaza grupul $nume_grup ..."
        sudo groupadd "$nume_grup"
    fi        
done < $group_file

while read line
do
set -x
	detalii_user=$(echo "$line" | cut -f1 -d" ")
	detalii_grup_principal=$(echo "$line" | cut -f2 -d" ")
	detalii_grup_secundar=$(echo "$line" | cut -f3 -d" ")
	home=`cut -f6 -d: <<<$detalii_user`
	user=`cut -f1 -d: <<<$detalii_user`
	gecos=`cut -f5 -d: <<<$detalii_user`
	shell=`cut -f7 -d: <<<$detalii_user`
    if [[ ! -d "$home" ]]
    then
        echo "Restaurarea directorului home pentru $user..."
        tar xzf "$backup_dir/$user-home-$user.tar.gz" -C / 2>/dev/null
        
    fi
    
    grup_principal=`cut -f2 -d- <<<$detalii_grup_principal| cut -f1 -d:`
    grupuri_secundare=`cut -f2 -d- <<<$detalii_grup_secundar`
    verf_g_s=`egrep ",$" <<<$grupuri_secundare`
    if [[ -n $verf_g_s ]]
    then
    	grupuri_secundare=`echo "$grupuri_secundare" | sed -r "s/,$//"`
    fi

    if [[ -n "$grupuri_secundare" ]]
    then
		echo "se creeaza user cu grupul principal si cele secundare"
        sudo useradd -c "$gecos" -d $home -m -g "$grup_principal" -G "$grupuri_secundare" -s $shell $user
        sudo chown -R $user "$home"
    else
		echo "se creaza user doar cu grup principal"
        sudo useradd -c "$gecos" -d $home -m -g "$grup_principal" -s $shell $user
        sudo chown -R $user "$home"
    fi

    sudo usermod -p $(egrep "^$user:" $shadow_file | cut -d: -f2) $user

done < $user_file

echo "Utilizatorii au fost creati cu succes pe noul sistem."
echo "Restaurarea directoarelor home a fost completa."
