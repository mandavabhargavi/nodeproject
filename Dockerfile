FROM
COPY package*.json ./
ENTRYPOINT ["npm", "start"]
