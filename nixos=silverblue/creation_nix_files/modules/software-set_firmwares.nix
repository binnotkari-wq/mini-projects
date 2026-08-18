##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;                                # pour avoir des firmware supplémentaire open-source (wifi...). 750 Mo.
  # hardware.enableAllFirmware = true;                                          # pour avoir des firmware closed source (matériel spécifique...)
}
