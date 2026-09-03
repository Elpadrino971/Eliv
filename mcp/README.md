# Serveur MCP VybzzZ

Expose la plateforme VybzzZ à un client MCP (Claude Desktop, un agent, un IDE
compatible…) sous forme d'**outils** que l'IA peut appeler en langage naturel :

| Outil | Ce qu'il fait |
|---|---|
| `get_stats` | Stats globales (fans, artistes, concerts, revenus, compte à rebours du 1er paiement) |
| `get_geo` | Répartition des utilisateurs par pays (+ points pour la carte) |
| `list_users` | Liste des utilisateurs (`type`: all/user/artist, `search`) |
| `list_artists` | Liste des artistes |
| `list_events` | Liste des concerts / événements |
| `list_meetings` | Réunions internes VIBE |
| `get_meeting` | Détail d'une réunion (notes, actions) par `id` |
| `meeting_assist` | Assistant IA de réunion (`points` / `reply` / `ask`) |

Le serveur parle à ton **API admin existante** (`api.vybzzz.online/api`). Il se
connecte une fois avec un compte admin, garde le token en cache et le
rafraîchit tout seul.

> **Version 1 : lecture + assistant IA.** Aucune action destructrice (pas de
> suppression / modification). On pourra ajouter des outils d'écriture plus tard,
> avec les garde-fous adaptés.

## Installation

```bash
cd mcp
npm install
cp .env.example .env   # puis remplis VYBZZZ_ADMIN_EMAIL / VYBZZZ_ADMIN_PASSWORD
```

Test rapide (doit afficher « prêt — API: … | outils: 8 ») :

```bash
VYBZZZ_ADMIN_EMAIL=... VYBZZZ_ADMIN_PASSWORD=... node server.js
```
(Ctrl+C pour quitter — en usage réel c'est le client MCP qui le lance.)

## Brancher sur Claude Desktop

Édite le fichier de config de Claude Desktop :

- **macOS** : `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows** : `%APPDATA%\Claude\claude_desktop_config.json`

Ajoute (adapte le chemin absolu vers `server.js`) :

```json
{
  "mcpServers": {
    "vybzzz": {
      "command": "node",
      "args": ["/chemin/absolu/vers/mcp/server.js"],
      "env": {
        "VYBZZZ_API_BASE": "https://api.vybzzz.online/api",
        "VYBZZZ_ADMIN_EMAIL": "ton-admin@vybzzz.online",
        "VYBZZZ_ADMIN_PASSWORD": "ton-mot-de-passe-admin"
      }
    }
  }
}
```

Redémarre Claude Desktop. Tu pourras alors demander, en langage naturel :

- « Combien d'utilisateurs VybzzZ et dans quels pays ? »
- « Liste mes artistes. »
- « Prépare-moi les arguments clés pour la réunion 3. »
- « On m'a dit "vos commissions sont trop hautes", rédige-moi une réponse (réunion 3). »

## Sécurité

- Le `.env` contient tes identifiants admin → **ne jamais le committer** (déjà
  ignoré par le `.gitignore` de ce dossier).
- Le serveur tourne **en local** (transport stdio) : les identifiants ne quittent
  pas ta machine, seuls des appels HTTPS vers ton API sont faits.
- Version 1 volontairement **en lecture seule** (sauf l'assistant IA qui ne fait
  que générer du texte).

## Ajouter des outils

Chaque outil est un objet dans le tableau `TOOLS` de `server.js` :
`{ name, description, inputSchema, run }`. `run(args)` renvoie l'objet à
retourner. Ajoute une entrée, redémarre le client, c'est tout.
