FROM node:10
COPY package*.json ./
ENTRYPOINT ["npm", "start"]
