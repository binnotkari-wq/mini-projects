Base conaissance Nixos / Silverblue

Ce qui a déjà été réfléchi, pour ne pas perdre de temps à vouloir réinventer l'eau chaude.

La plupart de ces comportement peuvent probablement être résolus avec un bon paramétrage. Mais on s'éloigne du système qui fonctionne "as is".



Ne pas faire ....


Ce qui ne marche pas :

- changer les répertoires de Gnome Boxes (Machines) version Flatpak.
- charger un iso ailleurs que depuis home avec Gnome Boxes (Machines) version Flatpak. Même avec flatpak override des autorisations, ca ne va pas.
- Fedora atomic : essayer de paramétrer la compression btrfs dans fstab : aucun effet. Reconnu par la communauté, bug upstream du à composefs.
- atomic-image-builder : essayer de l'installer dans brew alors que les outils de compilation ne sont pas présents sur l'hote (ce qui est le cas dans silverblue). Il faut installer la version podman proposée par le site.
- ryzenadj ne fonctionne pas lorsque secureboot est activé : ca ne marche pas, ni avec ryzenadj du repo rpm de ublue, ni en compilant ryzenadj. Il faut désactiver secureboot. DOmmage sur une distrib qui prend en charge secureboot. RyzenAdj accède aux MSR (Model-Specific Registers) directement via /dev/cpu/*/msr, et le mode lockdown du noyau que Secure Boot active sous Linux bloque justement cet accès (lockdown=integrity ou confidentiality selon la distro).
- quelle que soit la distribution : ne pas essayer de modifier les bases, les principes (partionnements, process d'installation, usine gaz et adaptation alambiquées...). Tout est faisable, mais ça génère un travail de maintenance, de documentation et de mémoire. Ca amène une exclusivité qui complique les diagnostiques lorsque quelque chose ne vas pas.
- zenity : ne pas installer dans une distrobox. Cela tire beaucoup de dépendances.
- gamescope dans une distrobox : les appels directs à wayland impliquent une execution directement depuis l'hôte, sans l'isolement d'un container.


Ce qui marche
- compression btrfs spécifiée en KARGS
- powertop peut être installé et exécuté dans une distrobox
- nix peut être installé dans une distrobox
- distrobox peut exposer les binaires à l'hôte avec des wrappers dans ~/.local/bin

Quelques bonnes référence de paramétrage réflechi et argumenté de Silverblue :
- https://lurkerlabs.com/fedora-silverblue-ultimate-post-install-guide/
- https://fedoraproject.org/wiki/Firefox_Hardware_acceleration?ref=lurkerlabs.com
- https://fedoraproject.org/wiki/Hardware_Video_Acceleration
- https://dev.to/archerallstars/my-opinionated-fedora-silverblue-setup-4o9p

Le mieux : laisser l'installateur faire le travail.


Concernant le partitionnement : au lieu de créer des sous-volumes supplémentaires, laisser le schema de partitions mis en place par l'installateur.

STEAM : on peut deplacer la bibliothèque et faire un lien ?

Ce qui est inutile :

- flatpak remote-modify --no-filter --enable flathub : ne sert à rien. Autant faire flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo car cette commande est idempotente. Si le repo existe, elle ne fait rien, s'il nexiste pas elle le remplace, et s'il existe en version filtrée, elle le remplace.
  

## Bon à savoir

### Dossiers utilisateur à sauvegarder

La copie sera immédiate sur un sous-volume, puisqu'on reste sur le même volume btrfs.

$HOME/.local/share/containers
$HOME/.var/app/org.gnome.Boxes


### Dossiers systèmes à sauvegarder

/var/lib/flatpak
/var/lib/containers

Mieux : un sous volume btrfs monté sur chacun de ces dossiers


## Paramètres de compression BTRFS

Exécution du script btrfs-compress-bench.sh puis analyse de Claude (02/09/22026)
--> compress=zstd:1 est le choix optimum.

Sur Silverblue, le paramètre de compression doit être passé au KARGS :

```
rpm-ostree kargs --delete="rootflags=subvol=root" --append="rootflags=subvol=root,compress=zstd:1"
```

Cela s'appliquera à l'ensemble de / y compris ses sous-volumes et y compris à travers composefs. C'est la seule façon à ce jour (02/09/2026) de mettre en place la compression btrfs sur / et ses sous-volumes, car les options de montage de / et de ses sous-volumes sont ignorées par OSTREE / composefs dans /etc/fstab.

Pour d'autres volumes que / (disque secondaire), on peut spécifier les paramètres de compression dans Gnome Disques, ou directement marquer le volume avec le paramètre.

```
sudo btrfs property set /mnt/disque_secondaire_monté compression zstd
```

Ce sera alors le niveau de compression zstd par défaut (3) qui sera enregistré.


Pour compresser des données déjà existantes :

```
sudo btrfs filesystem defragment -r -v -f -czstd /chemin/vers/données
```


### Exécution

```
benoit@fedora:~/Téléchargements$ sudo ./btrfs-compress-bench.sh
== Vérification des dépendances ==
== Provisionnement du dataset synthétique dans /var/tmp/btrfs-bench.EpcduF/dataset ==
-- Copie de fichiers texte réels --
-- Génération de logs synthétiques --
-- Copie de binaires réels (/usr/bin, /usr/lib) --
-- Génération des blobs pseudo-aléatoires (rapide, via openssl) --
-- Génération du fichier vmlike.img --
Dataset total : 924M

== Création de l'image btrfs (8G) ==
== Dataset original ==
Taille : 924M

-- Échauffement (résultat non retenu) --

Ordre de passage pour ce run : compress-force=zstd:1 compress=zstd:3 compress-force=zstd:3 compress=zstd:1

---- Cas : compress-force=zstd:1 (compress-force=zstd:1) ----
Temps de copie + sync : 9.800059234s
Processed 826 files, 6195 regular extents (6195 refs), 319 inline, 1065 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       77%      717M         924M         924M       
none       100%      704M         704M         704M       
zstd         5%       12M         219M         219M       
Temps de lecture complète (tar->/dev/null) : .030416059s

---- Cas : compress=zstd:3 (compress=zstd:3) ----
Temps de copie + sync : 8.512916325s
Processed 826 files, 5932 regular extents (5932 refs), 320 inline, 1141 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       77%      716M         924M         924M       
none       100%      704M         704M         704M       
zstd         5%       12M         219M         219M       
Temps de lecture complète (tar->/dev/null) : .025117815s

---- Cas : compress-force=zstd:3 (compress-force=zstd:3) ----
Temps de copie + sync : 7.882017113s
Processed 826 files, 5229 regular extents (5229 refs), 320 inline, 896 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       78%      721M         924M         924M       
none       100%      708M         708M         708M       
zstd         5%       12M         215M         215M       
Temps de lecture complète (tar->/dev/null) : .023801278s

---- Cas : compress=zstd:1 (compress=zstd:1) ----
Temps de copie + sync : 7.842759279s
Processed 826 files, 3837 regular extents (3837 refs), 319 inline, 1068 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       77%      717M         924M         924M       
none       100%      704M         704M         704M       
zstd         5%       12M         219M         219M       
Temps de lecture complète (tar->/dev/null) : .023219411s


== Résumé enregistré dans : /var/tmp/btrfs-bench.EpcduF/results.txt ==
(le répertoire temporaire sera supprimé à la sortie du script — copie ce fichier si tu veux le garder)
Copie sauvegardée : /root/btrfs-bench-results.txt

== Affichage final ==
== Dataset original ==
Taille : 924M

Ordre de passage pour ce run : compress-force=zstd:1 compress=zstd:3 compress-force=zstd:3 compress=zstd:1

---- Cas : compress-force=zstd:1 (compress-force=zstd:1) ----
Temps de copie + sync : 9.800059234s
Processed 826 files, 6195 regular extents (6195 refs), 319 inline, 1065 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       77%      717M         924M         924M       
none       100%      704M         704M         704M       
zstd         5%       12M         219M         219M       
Temps de lecture complète (tar->/dev/null) : .030416059s

---- Cas : compress=zstd:3 (compress=zstd:3) ----
Temps de copie + sync : 8.512916325s
Processed 826 files, 5932 regular extents (5932 refs), 320 inline, 1141 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       77%      716M         924M         924M       
none       100%      704M         704M         704M       
zstd         5%       12M         219M         219M       
Temps de lecture complète (tar->/dev/null) : .025117815s

---- Cas : compress-force=zstd:3 (compress-force=zstd:3) ----
Temps de copie + sync : 7.882017113s
Processed 826 files, 5229 regular extents (5229 refs), 320 inline, 896 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       78%      721M         924M         924M       
none       100%      708M         708M         708M       
zstd         5%       12M         215M         215M       
Temps de lecture complète (tar->/dev/null) : .023801278s

---- Cas : compress=zstd:1 (compress=zstd:1) ----
Temps de copie + sync : 7.842759279s
Processed 826 files, 3837 regular extents (3837 refs), 319 inline, 1068 fragments.
Type       Perc     Disk Usage   Uncompressed Referenced  
TOTAL       77%      717M         924M         924M       
none       100%      704M         704M         704M       
zstd         5%       12M         219M         219M       
Temps de lecture complète (tar->/dev/null) : .023219411s
```

### Analyse CLaude

Voici la lecture honnête de ces résultats.


En excution randomisés des différents cas + un run d'échauffement, le biais systémique disparaît complètement.
L'écart réel entre zstd:1 et zstd:3, une fois le bruit maîtrisé, reste faible (0.5 à 1.9s sur ~8-12s de copie, soit 5-20%) — cohérent avec les sources citées plus tôt (Fedora wiki, patch kernel 1.5.7) qui trouvaient un écart modeste.
Il reste du bruit résiduel (le contre-exemple à 1.9s dans l'autre sens) — normal sur un poste de bureau avec d'autres processus actifs, pas un banc dédié. Pour trancher plus finement, il faudrait 5-10 répétitions par option et comparer les médianes, comme fait le script Facebook original.


Sur ton usage (rootfs, dotfiles, config), la différence de vitesse et de ratio entre zstd:1 et zstd:3 est trop faible pour être un critère de choix déterminant — compress=zstd:1 reste un choix raisonnable et simple pour tes machines les moins puissantes (X240, L380), et zstd:3 convient très bien si tu préfères l'utiliser partout par simplicité de config.








## Configuration RAM


### A propos de l'emplacement des fichiers de configuration


Exemple pour zram-generator.conf : dans /etc/systemd/zram-generator.conf.d/ ou dans /etc/systemd/ ? (on voit d'origine un zram-generator.conf fourni par Fedora dans /etc/systemd/)

Les deux emplacements sont valides, mais ils ont un rôle différent :

/etc/systemd/zram-generator.conf → le fichier de configuration principal
/etc/systemd/zram-generator.conf.d/*.conf → des drop-ins (fragments qui viennent surcharger le fichier principal)

Le fichier de configuration principal est lu avant les drop-ins et a la priorité la plus basse ; les entrées des drop-ins écrasent celles du fichier principal. 
GitHub

Dans ton cas, comme Fedora Silverblue fournit déjà un zram-generator-defaults (le paquet dnf que tu as probablement, avec une config par défaut livrée par le vendor, souvent dans /usr/lib/systemd/zram-generator.conf ou équivalent), passer par le dossier conf.d/ est en fait le choix le plus propre : ça te permet de surcharger la config par défaut sans la modifier directement, ce qui est cohérent avec ta philosophie "pas de modif intrusive du système de base" sur une distro atomique/immuable comme Silverblue.

Petit détail à corriger : le nom du fichier dans conf.d/ ne doit pas obligatoirement s'appeler zram-generator.conf — n'importe quel nom se terminant en .conf fonctionne (les fichiers sont fusionnés par ordre alphabétique). Tu pourrais par exemple l'appeler /etc/systemd/zram-generator.conf.d/99-custom.conf pour plus de clarté, mais garder zram-generator.conf comme nom fonctionne aussi tant qu'il est dans le bon dossier.

En résumé : ta commande actuelle (écrire dans conf.d/) est correcte et c'est la bonne approche pour Silverblue.




### ZRAM

https://wiki.archlinux.org/title/Zram#Optimizing_swap_on_zram
swappiness agressif comme Bazzite pour favoriser ZRAM avant le swap disque
VMMC : https://fedoraproject.org/wiki/Changes/IncreaseVmMaxMapCount

On crée un fichier dédié dans /etc/sysctl.d/ pour ne pas polluer le sysctl.conf principal

