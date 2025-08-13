FROM node:18

# Set working directory
WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
RUN npm install

# Copy app source
COPY . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["node", "server.js"]
