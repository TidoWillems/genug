# 🚀 Release v0.2 – Setup & Helper Scripts

Dieses Release bringt eine komplette, selbsterklärende Pipeline für **Deploy & Setup**.  
Ziel: Jede*r, der das Repo klont, kann sofort starten – ohne Spezialwissen.  

---

## ✨ Neu

- **.deploy.env.example**  
  Beispiel-Datei für FTP/Deploy-Konfiguration

- **check_env.sh**  
  Sanity-Check für ENV-Variablen & Abhängigkeiten (`lftp`, `jq`, `python`)

- **404.html**  
  Minimal-Fehlerseite für nicht gefundene Seiten

- **robots.txt**  
  inkl. Sitemap-Verweis (`sitemap.xml`)

- **setup.sh**  
  Interaktives Skript: fragt FTP-Daten ab und schreibt `.deploy.env`

- **deploy_git.sh**  
  Variante von `deploy.sh` mit zusätzlichem Git-Sync (commit & push)

- **footer_patch.sh**  
  Ergänzt automatisch den Footer-Link zu `STATUS.md`

---

## 🛠 Getting Started

```bash
./setup.sh        # einmalig: FTP-Daten eingeben, .deploy.env erzeugen
./check_env.sh    # prüft, ob Abhängigkeiten und ENV stimmen
./deploy.sh       # nur FTP-Deploy
./deploy_git.sh   # FTP + Git commit/push
```

---

📖 Changelog

Siehe CHANGELOG.md für Details.

---

🔖 Tag: v0.2  
📅 Datum: 2025-09-01
