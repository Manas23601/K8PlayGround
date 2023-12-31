#!/bin/bash
source .env
# Install jq based on the operating system
os_name=$(uname -s)
if [ "$os_name" == "Darwin" ]; then
    brew install jq
else
    sudo apt-get install jq
fi

# Get the number of models from the config.json file
count=$(jq '.models | length' config.json)

# Generate docker-compose.yaml file
printf "version: '3'\nservices:\n" > docker-compose.yaml

# Generate Nginx configuration file
printf "events {}\n\nhttp {\n    server {\n        server_name ${DOMAIN_NAME};\n" > "${DOMAIN_NAME}.conf.d"

# Loop through each model
for ((i=0; i<$count; i++)); do
    # Get model details from config.json
    serviceName=$(jq -r ".models[$i].serviceName" config.json)
    modelBasePath=$(jq -r ".models[$i].modelBasePath" config.json)
    apiBasePath=$(jq -r ".models[$i].apiBasePath" config.json)
    containerPort=$(jq -r ".models[$i].containerPort" config.json)

    # Calculate the exposed port for the model
    exposedPort=$((8000 + i))

    # Get environment variables for the model
    environment=($(jq -r ".models[$i].environment | keys[]" config.json))

    # Add location block to Nginx configuration
    printf "            location ${apiBasePath}/ {\n                proxy_pass http://localhost:${exposedPort};\n            }\n" >> "${DOMAIN_NAME}.conf.d"


    # Add service details to docker-compose.yaml
    printf "  ${serviceName}:\n    build:\n      context: ${modelBasePath}\n    ports:\n      - ${exposedPort}:${containerPort}\n" >> docker-compose.yaml

    # Add environment variables to docker-compose.yaml
    if [[ ${#environment[@]} -gt 0 ]]; then
        printf "    environment:\n" >> docker-compose.yaml
    fi
    for key in "${environment[@]}"; do
        value=`jq -r '.models['$i'].environment["'$key'"]' config.json`
        printf "      - ${key}=${value}\n" >> docker-compose.yaml
    done
done

printf "    }\n}\n" >> "${DOMAIN_NAME}.conf.d"
