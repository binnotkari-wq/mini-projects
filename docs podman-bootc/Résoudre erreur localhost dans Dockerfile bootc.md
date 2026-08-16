# Résoudre erreur localhost dans Dockerfile bootc

**human** (Aug 15, 2026, 07:53 PM)

Claude, j'essaie de builder un container bootc en local, avec une source localhost :

[benoit@len-380:~/Git/fedora_custom-bootc]$ sudo podman build -t fedora_custom-bootc:latest .
[1/2] STEP 1/3: FROM scratch AS ctx
[1/2] STEP 2/3: COPY build_files /
--> Using cache 531c51d68bf4e1f7133290bb19af2fc625945f33dcb8a47fba39f1c39eee9b7f
--> 531c51d68bf4
[1/2] STEP 3/3: COPY system_files /system_files
--> Using cache 76271b9560d18a04c4f59cb7075f7de38646c09296bc5c34accff3061edefb7c
--> 76271b9560d1
[2/2] STEP 1/3: FROM localhost/fedora_reference-bootc:latest
Trying to pull localhost/fedora_reference-bootc:latest...
WARN[0000] Failed, retrying in 2s ... (1/3). Error: initializing source docker://localhost/fedora_reference-bootc:latest: pinging container registry localhost: Get "https://localhost/v2/": dial tcp [::1]:443: connect: connection refused 
WARN[0002] Failed, retrying in 2s ... (2/3). Error: initializing source docker://localhost/fedora_reference-bootc:latest: pinging container registry localhost: Get "https://localhost/v2/": dial tcp [::1]:443: connect: connection refused 
WARN[0004] Failed, retrying in 2s ... (3/3). Error: initializing source docker://localhost/fedora_reference-bootc:latest: pinging container registry localhost: Get "https://localhost/v2/": dial tcp [::1]:443: connect: connection refused 
Error: creating build container: unable to copy from source docker://localhost/fedora_reference-bootc:latest: initializing source docker://localhost/fedora_reference-bootc:latest: pinging container registry localhost: Get "https://localhost/v2/": dial tcp [::1]:443: connect: connection refused
[benoit@len-380:~/Git/fedora_custom-bootc]$

**assistant** (Aug 15, 2026, 07:53 PM)

{"start_timestamp":"2026-08-15T17:53:35.749143Z","stop_timestamp":"2026-08-15T17:53:39.750773Z","type":"thinking","thinking":"","summaries":[{"summary":"Identifié discordance entre tag d'image et référence Containerfile."}],"cut_off":false,"truncated":true,"hidden":false,"thinking_hidden":true}

Le souci vient du nom de l'image. Ton `podman load` a chargé l'image sous le tag `ghcr.io/binnotkari-wq/fedora_reference-bootc:latest`, mais ton Containerfile référence `localhost/fedora_reference-bootc:latest`. Comme ce nom exact n'existe pas dans le stockage local, Podman ne le traite pas comme "local uniquement" et tente un pull réseau — d'où l'erreur `connection refused` sur `localhost:443`.

Il suffit de retagger l'image importée avec le nom attendu :

```bash
sudo podman tag ghcr.io/binnotkari-wq/fedora_reference-bootc:latest localhost/fedora_reference-bootc:latest
```

Puis relance ton build :

```bash
sudo podman build -t fedora_custom-bootc:latest .
```

Petit point pour la suite : à chaque nouveau `.tar` chargé (nouvelle date de build), il faudra refaire ce tag, sauf si tu automatises ça dans ton `fork-init.sh`. Tu pourrais par exemple y ajouter directement une ligne du type :

```bash
sudo podman load -i "$TAR_PATH" | grep "Loaded image" | awk '{print $3}' | xargs -I{} sudo podman tag {} localhost/fedora_reference-bootc:latest
```

Ça évite d'avoir à retenir le tag exact à chaque itération offline.