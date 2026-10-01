FROM node:20-bookworm-slim

# Outils de build pour better-sqlite3 (module natif) + ffmpeg pour le studio web
# (STUDIO_WEB=1 : le navigateur de l'artiste envoie son flux, ffmpeg le pousse
# en RTMP vers Mux ; Debian bookworm : ffmpeg 5.1 avec x264, aac, rtmps/gnutls).
# ffmpeg en --no-install-recommends (évite pulseaudio, mesa…) ; la ligne des
# outils de build reste inchangée.
RUN apt-get update && apt-get install -y python3 make g++ \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Le port est fourni par l'hébergeur (Railway/Render) via $PORT ; 8002 par défaut.
ENV PORT=8002
# Sans ça, le backend tournait en mode "dev" en prod : JWT_SECRET faible non
# bloqué au démarrage, messages d'erreur bruts (SQL/chemins) renvoyés au client.
ENV NODE_ENV=production

EXPOSE 8002
CMD ["node", "src/server.js"]
