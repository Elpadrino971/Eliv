FROM node:20-bookworm-slim

# Outils de build pour better-sqlite3 (module natif)
RUN apt-get update && apt-get install -y python3 make g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

# Le port est fourni par l'hébergeur (Railway/Render) via $PORT ; 8002 par défaut.
ENV PORT=8002

EXPOSE 8002
CMD ["node", "src/server.js"]
