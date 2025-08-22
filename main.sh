#!/usr/bin/env bash

disable_ubuntu_report() {
    sudo ubuntu-report send no
    sudo apt remove ubuntu-report -y
}

remove_appcrash_popup() {
    sudo apt remove apport apport-gtk -y
}

remove_snaps() {
    while [ "$(snap list | wc -l)" -gt 0 ]; do
        for snap in $(snap list | tail -n +2 | cut -d ' ' -f 1); do
            sudo snap remove --purge "$snap" 2> /dev/null
        done
    done

    sudo systemctl stop snapd
    sudo systemctl disable snapd
    sudo systemctl mask snapd
    sudo apt purge snapd -y
    sudo rm -rf /snap /var/lib/snapd
    for userpath in /home/*; do
        sudo rm -rf $userpath/snap
    done
    cat <<-EOF | sudo tee /etc/apt/preferences.d/nosnap.pref
	Package: snapd
	Pin: release a=*
	Pin-Priority: -10
	EOF
}

disable_terminal_ads() {
    sudo sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news 2>/dev/null
    sudo pro config set apt_news=false
}

update_system() {
    sudo apt update && sudo apt upgrade -y
}

cleanup() {
    sudo apt autoremove -y
}

setup_flathub() {
    sudo apt install flatpak -y
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo apt install --install-suggests gnome-software -y
}

set_fonts() {
	gsettings set org.gnome.desktop.interface monospace-font-name "Maple Mono NF 11"
	gsettings set org.gnome.desktop.interface font-name 'Inter 11'
    mkdir -p ~/.local/share/fonts
    # TODO: Add logic to get the latest version always
    sudo wget -O /tmp/MapleMono-NF-unhinted.zip https://github.com/subframe7536/maple-font/releases/download/v7.5/MapleMono-NF-unhinted.zip
    unzip /tmp/MapleMono-NF-unhinted.zip -d ~/.local/share/fonts
    fc-cache -f -v

    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
    sudo apt install ttf-mscorefonts-installer -y
}

setup_vanilla_gnome() {
    sudo apt install qgnomeplatform-qt5 -y
    sudo apt install qgnomeplatform-qt6 -y
    sudo apt install gnome-session fonts-inter adwaita-icon-theme gnome-backgrounds gnome-tweaks vanilla-gnome-default-settings gnome-shell-extension-manager -y && sudo apt remove ubuntu-session yaru-theme-gnome-shell yaru-theme-gtk yaru-theme-icon yaru-theme-sound -y
    set_fonts
    restore_background
}

restore_background() {
    gsettings set org.gnome.desktop.background picture-uri 'file:///usr/share/backgrounds/gnome/blobs-l.svg'
    gsettings set org.gnome.desktop.background picture-uri-dark 'file:///usr/share/backgrounds/gnome/blobs-l.svg'
}

install_adwgtk3() {
    # TODO: Add logic to get the latest version always
    wget -O /tmp/adw-gtk3.tar.xz https://github.com/lassekongo83/adw-gtk3/releases/download/v6.2/adw-gtk3v6.2.tar.xz
    sudo tar -xf /tmp/adw-gtk3.tar.xz -C /usr/share/themes/
    if command -v flatpak; then
        flatpak install -y runtime/org.gtk.Gtk3theme.adw-gtk3-dark
        flatpak install -y runtime/org.gtk.Gtk3theme.adw-gtk3
    fi
}

install_icons() {
    sudo apt install git -y
    sudo add-apt-repository ppa:papirus/papirus
    sudo apt-get update
    sudo apt-get install papirus-icon-theme
    gsettings set org.gnome.desktop.interface icon-theme Papirus
    gsettings set org.gnome.desktop.interface accent-color blue
}

setup_dev_tools() {
    # deps
    sudo apt install -y git curl wget unzip build-essential

    # starship
    curl -sS https://starship.rs/install.sh | sh

    # eza (ls alternative)
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza

    # bat
    sudo apt install -y bat
    mkdir -p ~/.local/bin
    ln -s /usr/bin/batcat ~/.local/bin/bat

    # mise
    curl https://mise.run | sh
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
    ~/.local/bin/mise use --global node@22
    source ~/.bashrc
    npm i -g npm pnpm bun

    # Opencoed
    curl -fsSL https://opencode.ai/install | bash

    # wireguard
    sudo apt install -y wireguard
    wget -O /tmp/wireguird_amd64.deb https://github.com/UnnoTed/wireguird/releases/download/v1.1.0/wireguird_amd64.deb
    sudo dpkg -i /tmp/wireguird_amd64.deb

    # zed
    curl -f https://zed.dev/install.sh | sh

    # vscode
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    sudo apt update
    sudo apt install -y code

    # github cli
    (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y
	git config --global user.name "Davi Oliveira"
	git config --global user.email "davioliveira.java@gmail.com"
	git config --global pull.rebase true
	git config --global push.autoSetupRemote true

	# docker
	# Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker "$USER"

    # ghostty
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
    sudo apt remove -y gnome-terminal

    # fish
    sudo apt-add-repository ppa:fish-shell/release-4
    sudo apt update
    sudo apt install -y fish

    # dotfiles
    setup_dotfiles
}

setup_dotfiles() {
    git clone https://github.com/davioliveira-dev/dotfiles.git ~/.dotfiles
    # Moves the content of the dotfiles folder to the home directory
    cp -r ~/.dotfiles/. ~/
    # Removes the dotfiles folder
    rm -rf ~/.dotfiles
    rm -rf ~/.git
}

install_flatpaks() {
    flatpak install -y dev.vencord.Vesktop io.beekeeperstudio.Studio io.github.flattool.Ignition dev.deedles.Trayscale org.gnome.World.PikaBackup io.gitlab.librewolf-community dev.qwery.AddWater org.localsend.localsend_app com.microsoft.Edge md.obsidian.Obsidian
}

ask_reboot() {
    echo 'Reboot now? (y/n)'
    while true; do
        read choice
        if [[ "$choice" == 'y' || "$choice" == 'Y' ]]; then
            sudo reboot
            exit 0
        fi
        if [[ "$choice" == 'n' || "$choice" == 'N' ]]; then
            break
        fi
    done
}

msg() {
    tput setaf 2
    echo "[*] $1"
    tput sgr0
}

error_msg() {
    tput setaf 1
    echo "[!] $1"
    tput sgr0
}

enable_appindicator() {
    gsettings set org.gnome.shell enabled-extensions "['ubuntu-appindicators@ubuntu.com']"
}

print_banner() {
    echo 'daviziks ubuntu setup'
}

show_menu() {
    echo 'Choose what to do: '
    echo '1 - Apply everything'
    echo 'q - Exit'
    echo
}

main() {
    while true; do
        print_banner
        show_menu
        read -p 'Enter your choice: ' choice
        case $choice in
        1)
            auto
            msg 'Done!'
            ask_reboot
            ;;
        q)
            exit 0
            ;;
        *)
            error_msg 'Wrong input!'
            ;;
        esac
    done

}

auto() {
    msg 'Updating system'
    update_system
    msg 'Disabling ubuntu report'
    disable_ubuntu_report
    msg 'Removing annoying appcrash popup'
    remove_appcrash_popup
    msg 'Removing terminal ads (if they are enabled)'
    disable_terminal_ads
    msg 'Deleting everything snap related'
    remove_snaps
    msg 'Setting up flathub'
    setup_flathub
    msg 'Installing vanilla Gnome session'
    setup_vanilla_gnome
    enable_appindicator
    msg 'Install adw-gtk3'
    install_adwgtk3
    msg 'Installing icons'
    install_icons
    msg 'Installing dev tools'
    setup_dev_tools
    msg 'Installing flatpaks'
    install_flatpaks
    msg 'Cleaning up'
    cleanup
}

(return 2> /dev/null) || main
