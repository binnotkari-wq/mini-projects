{ config, lib, pkgs, ... }:

{
  # Gestion de l'énergie et des fréquences
  # Le driver amd_pstate est bien plus efficace que l'ancien acpi-cpufreq sur Zen 2+
  # Active le support du Precision Boost et la gestion thermique
  boot.kernelParams = [ "amd_pstate=active" ];
  boot.kernelModules = [
    "amd-pstate"
    "msr"
    "hwmon"
    "k10temp" # Température du processeur Ryzen. Ne pas utiliser zenpower, qui n'est pas intégré au kernel, et qui n'a pas plus de fonctions.
    "kvm-amd" # Déjà déclaré dans hardware-configuration.nix, mais on le laisse ici aussi même si c'est redontant.
  ];
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = true; # Déjà déclaré dans hardware-configuration.nix, mais on le laisse ici aussi même si c'est redontant.
}
