# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, inputs, ... }:

let
  sysmonPkg = pkgs.callPackage ../../pkgs/sysmon-for-linux/package.nix { };
  srtcamPkg = pkgs.callPackage ../../pkgs/srtcam/package.nix {
    srtcamSrc = inputs.srtcam;
  };
in

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = true;

  # Load v4l2loopback module at boot for use with OBS and other video applications.
  boot.extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];
  boot.kernelModules = ["v4l2loopback"];
  # unload kernel modules that are not needed and have had security vulnerabilities in the past.
  boot.extraModprobeConfig = ''
    options v4l2loopback exclusive_caps=1 max_buffers=2 video_nr=10 card_label="Virtual Camera"
    install esp4 ${pkgs.coreutils}/bin/false
    install esp6 ${pkgs.coreutils}/bin/false
    install rxrpc ${pkgs.coreutils}/bin/false
  '';
  boot.blacklistedKernelModules = [
    "esp4"
    "esp6"
    "rxrpc"
  ];

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Asia/Tokyo";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ja_JP.UTF-8";
    LC_IDENTIFICATION = "ja_JP.UTF-8";
    LC_MEASUREMENT = "ja_JP.UTF-8";
    LC_MONETARY = "ja_JP.UTF-8";
    LC_NAME = "ja_JP.UTF-8";
    LC_NUMERIC = "ja_JP.UTF-8";
    LC_PAPER = "ja_JP.UTF-8";
    LC_TELEPHONE = "ja_JP.UTF-8";
    LC_TIME = "ja_JP.UTF-8";
  };

  i18n.inputMethod = {
    type = "fcitx5";
    enable = true;
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-mozc
      fcitx5-gtk
    ];
  };

  fonts = {
    packages = (with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      udev-gothic-nf
    ]);
    fontDir.enable = true;
    fontconfig = {
      defaultFonts = {
        serif = [
          "Noto Serif CJK JP"
          "Noto Color Emoji"
        ];
        sansSerif =[
          "UDEV Gothic NFLG"
          "Noto Sans CJK JP"
          "Noto Clor Emoji"
        ];
        monospace = [
          "UDEV Gothic NFLG"
          "Noto Sans CJK JP"
          "Noto Clor Emoji"
        ];
        emoji = ["Noto Color Emoji"];
      };
    };
  };

  # Virtualisation
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };


  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.iwate = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "podman" "video" ];
  };

  # Allow flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Allow iwate to use custom substituters
  nix.settings.trusted-users = [ "root" "iwate" ];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
  #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
  #  wget
    sysmonPkg
    srtcamPkg
  ];

  environment.etc."srtcam/config.toml".text = ''
    listen_port = 5000
    srt_latency_ms = 30
    latency_profile = "ultra-low"
    loopback_device = "/dev/video10"
    frame_width = 1280
    frame_height = 720
    fps = 30
    ffmpeg_analyzeduration_us = 0
    ffmpeg_probesize_bytes = 32768
  '';

  environment.etc."sysmon/config.xml".text = ''
    <Sysmon schemaversion="4.22">
      <EventFiltering>
        <NetworkConnect onmatch="exclude">
          <DestinationHostname condition="is">google.com</DestinationHostname>
          <DestinationHostname condition="end with">.google.com</DestinationHostname>
          <DestinationHostname condition="end with">.googleapis.com</DestinationHostname>
          <DestinationIp condition="is">0.0.0.0/32</DestinationIp>
        </NetworkConnect>
        <DnsQuery onmatch="exclude">
          <QueryName condition="is">google.com</QueryName>
          <QueryName condition="end with">.google.com</QueryName>
          <QueryName condition="end with">.googleapis.com</QueryName>
        </DnsQuery>
      </EventFiltering>
    </Sysmon>
  '';

  systemd.tmpfiles.rules = [
    "d /opt/sysmon 0700 root root -"
    "d /opt/sysinternalsEBPF 0700 root root -"
  ];

  systemd.services.sysmon = {
    enable = true;
    description = "Sysmon for Linux";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "forking";
      WorkingDirectory = "/opt/sysmon";
      ExecStart = "${sysmonPkg}/bin/sysmon -i /opt/sysmon/config.xml -service";
      ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      Restart = "on-failure";
      RestartSec = 10;
      LimitMEMLOCK = "infinity";
    };
    preStart = ''
      install -m 0700 -d /opt/sysmon
      install -m 0700 -d /opt/sysinternalsEBPF
      install -m 0600 /etc/sysmon/config.xml /opt/sysmon/config.xml

      for obj in ${sysmonPkg}/share/sysmon/*.o; do
        install -m 0600 "$obj" /opt/sysmon/
      done

      # Sysinternals eBPF loader hard-codes /opt/sysinternalsEBPF paths.
      install -m 0600 ${sysmonPkg}/share/sysmon/sysinternalsEBPFrawSock.o /opt/sysinternalsEBPF/
      install -m 0600 ${sysmonPkg}/share/sysmon/sysinternalsEBPFmemDump.o /opt/sysinternalsEBPF/
      install -m 0600 ${sysmonPkg}/share/sysmon/offsets.json /opt/sysinternalsEBPF/
      ln -sfn /opt/sysinternalsEBPF/offsets.json /opt/sysinternalsEBPF/sysinternalsEBPF_offsets.conf

      touch /opt/sysmon/eula_accepted
      chmod 0600 /opt/sysmon/eula_accepted

      # Store argv/argc used by Sysmon for service restarts and config reloads.
      printf '\004\000\000\000' > /opt/sysmon/argc
      printf '%s\0' '${sysmonPkg}/bin/sysmon' '-i' '/opt/sysmon/config.xml' '-service' > /opt/sysmon/argv
      chmod 0600 /opt/sysmon/argc /opt/sysmon/argv
    '';
  };

  systemd.services.srtcam = {
    description = "srtcam SRT listener service";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "simple";
      User = "iwate";
      Group = "users";
      ExecStart = "${srtcamPkg}/bin/srtcam --config /etc/srtcam/config.toml";
      Restart = "always";
      RestartSec = 2;
      Environment = [ "RUST_LOG=info" ];
    };
  };

  # UDisks2 provides privileged mount operations; automount is handled in user session.
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
      userServices = true;
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.niri.enable = true;

  # gnome-keyring (VSCodeのGitHub認証情報保存に必要)
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "iwate" ];
  };
  # List services that you want to enable:
  services.displayManager.sddm = {
    enable = true;
    wayland = {
      enable = true;
      compositor = "kwin";
    };
  };
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  networking.firewall = {
    enable = true;
    allowPing = false;
    logRefusedConnections = true;
    rejectPackets = true;

    # Inbound is denied by default. Keep explicit allow lists empty.
    allowedTCPPorts = [ ];
    allowedUDPPorts = [ 5000 ];

  };

  networking.nftables = {
    enable = true;
    ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority 0; policy drop;

          iifname "lo" accept
          ct state established,related accept

          # Allow inbound UDP on port 5000.
          udp dport 5000 ct state new accept

          # mDNS (Bonjour/Avahi).
          udp dport 5353 accept

          # ICMP/ICMPv6 are needed for basic network health and IPv6.
          ip protocol icmp icmp type echo-request drop
          ip protocol icmp accept
          ip6 nexthdr icmpv6 accept
        }

        chain forward {
          type filter hook forward priority 0; policy drop;
        }

        chain output {
          type filter hook output priority 0; policy drop;

          oifname "lo" accept
          ct state established,related accept

          # Required outbound access.
          tcp dport { 22, 80, 443, 3389 } ct state new accept

          # DNS.
          udp dport 53 ct state new accept
          tcp dport 53 ct state new accept

          # mDNS (Bonjour/Avahi).
          udp dport 5353 accept

          # NTP.
          udp dport 123 ct state new accept

          # DHCPv4 and DHCPv6 client traffic.
          ip protocol udp udp sport 68 udp dport 67 accept
          ip6 nexthdr udp udp sport 546 udp dport 547 accept
        }
      }
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "26.05"; # Did you read the comment?

}
