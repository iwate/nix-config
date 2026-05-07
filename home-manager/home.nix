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
    libnotify
    ripgrep
    bat
    fd
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
      zircolite-sysmon = "${config.home.homeDirectory}/nix-config/home-manager/scripts/run-zircolite-podman.sh";
      export-sysmon-log = "${config.home.homeDirectory}/nix-config/home-manager/scripts/export-sysmon-log.sh";
      connect-work-rdp = "${config.home.homeDirectory}/nix-config/home-manager/scripts/connect-work-rdp.sh";
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

  systemd.user.services.check-updates = {
    Unit = {
      Description = "Check for system updates";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/nix-config/check-updates.sh";
    };
  };

  systemd.user.timers.check-updates = {
    Unit = {
      Description = "Check for system updates every 4 hours";
      Requires = "check-updates.service";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "4h";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

}
