{ config, pkgs, lib, ... }:

{
  # Chargement du pilote graphique au niveau du noyau
  # Indispensable pour que le GPU soit reconnu avant même le chargement de l'interface
  boot.initrd.kernelModules = [ "i915" ];

  # Couche d'accélération matérielle (Espace utilisateur)
    hardware.graphics.extraPackages = with pkgs; [
      # --- Accélération Vidéo (VA-API) ---

      # Pour l'i3 de 8e gén (et tout processeur Broadwell ou plus récent)
      intel-media-driver

      # Pour l'i5 de 4e gén (et architectures Haswell/anciennes)
      intel-vaapi-driver

      # Traduction VDPAU vers VA-API (pour les anciens logiciels)
      libvdpau-va-gl
    ];

  # Utilitaires de diagnostic (Inclus dans l'ISO pour tests rapides)
  environment.systemPackages = with pkgs; [
    mesa-demos # Fournit glxinfo et glxgears
    intel-gpu-tools   # Permet de lancer 'intel_gpu_top' pour voir la charge GPU
  ];
}
