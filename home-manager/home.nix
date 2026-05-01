{ config, pkgs, inputs, ... }:
{
  programs.home-manager.enable = true;
  home.stateVersion = "25.11"; 

  home.username = "iwate";
  home.homeDirectory = "/home/iwate";

  home.packages = with pkgs; [
    firefox
    swaylock
    alacritty
    freerdp
    xwayland-satellite
    networkmanagerapplet
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default
	  vscode
    git
    slack
    obsidian
  ];

  home.file.".config/git/config".source = ./dotfiles/.gitconfig;
  home.file.".config/fcitx5/config".source = ./dotfiles/fcitx5-config;
  home.file.".config/fcitx5/profile".source = ./dotfiles/fcitx5-profile;
  home.file.".config/mozc/config1.db".source = ./dotfiles/mozc-config1.db;
  home.file.".config/niri/config.kdl".source = ./dotfiles/niri-config.kdl;
  home.file.".config/niri/config.kdl".force = true;
  home.file.".config/noctalia/colors.json".source = ./dotfiles/noctalia-colors.json;
  home.file.".config/noctalia/settings.json".source = ./dotfiles/noctalia-settings.json;

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
            /f /kbd:layout:Japanese /kbd:remap:0x3a=0nixx64 /scale:140
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
