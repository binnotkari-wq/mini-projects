{ config, lib, pkgs, ... }:

{
  # 1. Gestion de l'énergie et des fréquences (P-State)
  # On active thermald pour éviter le throttling thermique brutal
  services.thermald.enable = true;

  # laisser power-profiles-daemon gérer la batterie. (activé par défat et
  # implicitement sous nixos)
  # 2. Configuration de TLP pour un contrôle fin (optionnel mais recommandé). En cas de blocage de build, désactiver toute cette partie. Mais ca fonctionne, actuellement sur le X240.
  # services.power-profiles-daemon.enable = false; # on desactive celui-ci, moins efficace que TLP, sinon ils entrent en conflit
  # services.tlp = {
  #   enable = true;
  #   settings = {
  #     # Utilise le driver intel_pstate
  #     CPU_SCALING_GOVERNOR_ON_AC = "performance";
  #     CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

  #     # Energy Performance Preference (EPP)
  #     CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
  #     CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Fréquences limites (en pourcentage)
  #     CPU_MIN_PERF_ON_AC = 0;
  #     CPU_MAX_PERF_ON_AC = 100;
  #     CPU_MIN_PERF_ON_BAT = 0;
  #     CPU_MAX_PERF_ON_BAT = 60; # Limite sur batterie pour l'autonomie
  #   };
  # };

  boot.kernelModules = ["kvm-intel"];
  hardware.cpu.intel.updateMicrocode = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";


  # 3. Paramètres du Kernel pour forcer Intel P-State si nécessaire
  boot.kernelParams = [ "intel_pstate=active" ];

  # 4. Installation logiciel Undervolting (Intel)
  environment.systemPackages = with pkgs; [
    undervolt      # Pour vérifier l'état actuel : sudo undervolt --read
    # attention, cet outil ne fonctionne plus sur les CPU Intel depuis la génération Comet Lake (10e gen) — Intel a verrouillé le MSR via microcode en réponse à Plundervolt. 
  ];
}
