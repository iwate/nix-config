{ config, pkgs, inputs, ... }:
let
  # 接続用スクリプトを定義
  rdpScript = pkgs.writeShellScriptBin "connect-work-rdp" ''
    # 1Password CLI とデスクトップアプリを連携させるための環境変数
    export OP_BIOMETRIC_UNLOCK_ENABLED=true
    # ソケットのパスを明示的に指定（NixOSのデフォルト）
    #export SSH_AUTH_SOCK=$HOME/.1password/agent.sock

    
    PASS=$(${pkgs._1password-cli}/bin/op read op://Private/RDP/password --debug)
    HOST=$(${pkgs._1password-cli}/bin/op read op://Private/RDP/host)
    USER=$(${pkgs._1password-cli}/bin/op read op://Private/RDP/username)
    DOMAIN=$(${pkgs._1password-cli}/bin/op read op://Private/RDP/domain)
    GW=$(${pkgs._1password-cli}/bin/op read op://Private/RDP/gateway)

    echo "$PASS" | ${pkgs.freerdp}/bin/xfreerdp /from-stdin \
      /v:"$HOST" \
      /u:"$USER" \
      /d:"$DOMAIN" \
      /gateway:g:"$GW" \
      /f /kbd:layout:Japanese /kbd:remap:0x15d=0x64 /scale:140
  '';
in
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
            /f /kbd:layout:Japanese /kbd:remap:0x15d=0x64 /scale:140
        )
      '';
    };
  };

  xdg.desktopEntries = {
    rdp-work = {
      name = "RDP(work)";
      genericName = "Connect to workstation";
      # 生成したスクリプトをフルパスで実行
      exec = "${pkgs.bash}/bin/bash -ic connect-work-rdp";
      terminal = false;
      categories = [ "Network" "RemoteAccess" ];
    };
  };

}
