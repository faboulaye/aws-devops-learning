# Simple production image for the Node + Express app
FROM node:18-alpine AS base

WORKDIR /app
ENV NODE_ENV=production

# Install dependencies (only production)
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# Copy app source (no dev files)
COPY app ./app

EXPOSE 3000

# Run as non-root for better security
USER node

CMD ["node", "app/server.js"]


