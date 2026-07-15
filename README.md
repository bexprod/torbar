# TorMenu 🧅

**TorMenu** est une application minimaliste pour la barre des menus macOS. Elle permet de surveiller le statut de votre instance **Tor** locale (gérée par Homebrew), d'afficher votre adresse IP Tor actuelle, de la copier en un clic, et d'offrir des raccourcis rapides pour changer d'IP, réparer la connexion ou contrôler le service Tor.

---

## Fonctionnalités

* **Icônes de statut dynamiques** dans la barre des menus :
  * 🧅 : Tor est connecté au réseau (Bootstrapped 100%).
  * 🟡 : Tor démarre ou cherche à se connecter.
  * ⚪ : Tor est arrêté ou inaccessible.
* **Affichage & Copie de l'IP active** : Affiche l'adresse IP publique de votre circuit Tor actuel. Cliquez sur la ligne pour copier directement l'IP dans votre presse-papiers avec une notification macOS native.
* **Nouvelle Identité (Changer d'IP)** : Force le renouvellement du circuit Tor pour obtenir instantanément une nouvelle IP (via le port de contrôle ou redémarrage de secours).
* **Réparer Tor** : Raccourci de dépannage automatique qui arrête Tor, efface le cache de consensus local (`cached-*`), et redémarre le service. Idéal si Tor est "bloqué" à 75% ou n'arrive plus à ouvrir de circuits.
* **Commandes de contrôle direct** : Démarrer, Arrêter et Redémarrer Tor en un clic.
* **Accès rapide aux logs** : Ouvre le fichier journal `/opt/homebrew/var/log/tor.log` pour le diagnostic.
* **Aide à la configuration** : Un guide rapide intégré pour configurer vos navigateurs, scripts et terminaux.

---

## Prérequis

Tor doit être installé sur votre Mac via Homebrew :
```bash
brew install tor
```

### Configuration recommandée (Port de contrôle)
Pour que la fonctionnalité **Nouvelle Identité (Changer d'IP)** soit instantanée (sans avoir à redémarrer tout le service Tor), activez le port de contrôle local de Tor :

1. Éditez votre fichier de configuration `/opt/homebrew/etc/tor/torrc` (créez-le s'il n'existe pas) :
   ```bash
   nano /opt/homebrew/etc/tor/torrc
   ```
2. Ajoutez la ligne suivante :
   ```text
   ControlPort 9051
   ```
3. Redémarre Tor pour appliquer :
   ```bash
   brew services restart tor
   ```

---

## Installation et Lancement

1. **Cloner ou télécharger** ce dépôt.
2. Ouvrez un terminal dans le dossier et lancez le script :
   ```bash
   chmod +x run_tormenu.sh
   ./run_tormenu.sh
   ```
   Le script va compiler automatiquement le fichier `TorMenu.swift` et démarrer l'application en arrière-plan.

---

## Configuration du Proxy

Par défaut, Tor écoute en tant que proxy SOCKS5 local sur :
* **Hôte** : `127.0.0.1` (ou `localhost`)
* **Port** : `9050`

### 1. Terminal (cURL, Wget, etc.)
Pour rediriger tout le trafic de votre session de terminal en cours à travers Tor :
```bash
export ALL_PROXY=socks5h://127.0.0.1:9050
```
*Note : L'utilisation du schéma `socks5h://` garantit que les résolutions DNS sont également effectuées par le nœud de sortie Tor, évitant ainsi les fuites DNS.*

Pour tester dans le terminal :
```bash
curl https://check.torproject.org/api/ip
```

### 2. Navigateur Web (Firefox - Recommandé)
1. Allez dans **Paramètres** > **Paramètres réseau**.
2. Cliquez sur **Paramètres...**
3. Sélectionnez **Configuration manuelle du proxy**.
4. Remplissez uniquement le champ **Hôte SOCKS** avec `127.0.0.1` et le **Port** avec `9050`.
5. Cochez **SOCKS v5**.
6. Cochez l'option **Activer DNS via SOCKS v5** (très important pour la confidentialité).

### 3. Scripts Python
```python
import requests

proxies = {
    'http': 'socks5h://127.0.0.1:9050',
    'https': 'socks5h://127.0.0.1:9050'
}

response = requests.get('https://check.torproject.org/api/ip', proxies=proxies)
print(response.json())
```

---

## Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.
