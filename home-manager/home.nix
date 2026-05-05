{ config, pkgs, inputs, ... }:
let 
  dotfilesPath = "${config.home.homeDirectory}/nix-config/home-manager/dotfiles"; 
in
{
  programs.home-manager.enable = true;
  home.stateVersion = "25.11"; 

  home.username = "iwate";
  home.homeDirectory = "/home/iwate";

  home.packages = with pkgs; [
    firefox
    swaylock
    kitty
    freerdp
    xwayland-satellite
    networkmanagerapplet
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
	  vscode
    git
    slack
    obsidian
    nautilus
    gnome-themes-extra
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    gtk4.extraCss = ''
      .nautilus-window {
        background: rgba(20, 20, 30, 0.78);
        background-image: none;
      }
      .nautilus-window .view {
        background: rgba(0,0,0,0);
        background-image: none;
      }
      .nautilus-window .sidebar-pane {
        background: rgba(0,0,0,0.20);
        background-image: none;
        box-shadow: none;
      }
    '';
    # gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    # gtk4.extraConfig.gtk-application-prefer-dark-theme = 1;
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  home.file.".config/git/config".source = ./dotfiles/.gitconfig;
  home.file.".config/fcitx5/config".source = ./dotfiles/fcitx5-config;
  home.file.".config/fcitx5/profile".source = ./dotfiles/fcitx5-profile;
  home.file.".config/mozc/config1.db".source = ./dotfiles/mozc-config1.db;
  home.file.".config/niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/niri-config.kdl";
  home.file.".config/niri/config.kdl".force = true;
  home.file.".config/noctalia/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/noctalia-settings.json";
  home.file.".config/noctalia/settings.json".force = true;
  home.file.".config/kitty/kitty.conf".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/kitty.conf";
  home.file.".config/kitty/kitty.conf".force = true;
  home.file.".config/Code/User/settings.json".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/vscode-settings.json";
  home.file.".config/Code/User/settings.json".force = true;

  programs.bash = {
    enable = true;
    shellAliases = {
      connect-work-rdp = ''
        (
          PASS=$(op read op://Private/RDP/password)
          HOST=$(op read op://Private/RDP/host)
          USER=$(op read op://Private/RDP/username)
          DOMAIN=$(op read op://Private/RDP/domain)
          GW=$(op read op://Private/RDP/gateway)

          echo "$PASS" | DISPLAY=:0 ${pkgs.freerdp}/bin/xfreerdp /from-stdin \
            /v:"$HOST" \
            /u:"$USER" \
            /d:"$DOMAIN" \
            /gateway:g:"$GW" \
            /f /kbd:layout:Japanese /kbd:remap:0x3a=0x64 /scale:140
        )
      '';
    };
  };

  # gnome-keyringをWaylandセッションで使えるようにする
  home.sessionVariables = {
    GNOME_KEYRING_CONTROL = "/run/user/\${UID}/keyring";
    SSH_AUTH_SOCK = "/run/user/\${UID}/keyring/ssh";
  };

  xdg.desktopEntries = {
    rdp-work = {
      name = "RDP(work)";
      genericName = "Connect to workstation";
      exec = "${pkgs.bash}/bin/bash -ic connect-work-rdp";
      terminal = false;
      categories = [ "Network" "RemoteAccess" ];
    };
  };

}
