#Lightweight
FROM node:18-alpine

#Set the working directory inside the container
WORKDIR /app

#Copy only the dependency manifest files first to take advantage of layer-caching
COPY package*.json ./

#Install the production dependencies
RUN nmp install --omit=dev

#Lastly, copy the rest of the source code
COPY ..

#Declare that the application is listening on port 3000
EXPOSE 3000

#Start the application
CMD ["node", "server.js"]