sudo chmod 777 -R ../GitHub_Analyzer_API

target=${1:-"api"}
buildtype=${2:-"lambda"}
echo "Target = $target"
echo "Buildtype = $buildtype"

#-----------------------------------------------
#---- Setup necessary ENV variables ------------
#-----------------------------------------------
branch_name=$(git symbolic-ref -q HEAD)
branch_name=${branch_name##refs/heads/}
export branch_name=${branch_name:-HEAD}

if [ $branch_name == "staging" ]; then
    echo "******Running Staging Environment******"
    export yarntarget="develop"
    export NODE_ENV="development"
    export dbname="stagedb"
    export dnsprefix='stage-autograde'
    export fromsuffix='sgage-autograde'
    export tosuffix='stage-autograde'
    export ecrstage='stage-autograde'

elif [ $branch_name == "prod" ]; then
    echo "******Running Production Environment******"
    export yarntarget="start"
    export NODE_ENV="production"
    export dbname="proddb"
    export dnsprefix='autograde'
    export fromsuffix='autograde'
    export tosuffix='autograde'
    export ecrstage='autograde'    
else
    echo "******Running Development Environment******"
    export yarntarget="develop"
    export NODE_ENV="development"
    export dbname="devdb"
    export dnsprefix='dev-autograde'
    export fromsuffix='dev-autograde'
    export tosuffix='dev-autograde'
    export ecrstage='dev-autograde'    
fi

#========================================= 
#       write Dockerfile
#=========================================
if [ $buildtype == "local" ]; then
    echo "Using Dockerfile.local ... "
    name="autog"
    port=5000
    tport=5000
    cp Dockerfile.${target}.local Dockerfile
else
    echo "Using Dockerfile.aws.lambda ... "
    name="autoglambda"
    port=9000
    tport=8080
    cp Dockerfile.${target}.lambda Dockerfile    
fi

#=========================================
#       write docker-compose.yml
#=========================================

cat <<EOF > docker-compose.yml
version: "3"
services:
  $name:
    container_name: $name
    build: .
    image: $name:latest
    restart: unless-stopped
    volumes:
      - /mnt/efs:/mnt/efs
    expose:
      - $tport 
    ports:
      - "$port:$tport"

EOF

#    network_mode: "host"    

#-----------------------------------------------
#---- build ------------
#-----------------------------------------------
docker-compose down $name

res=$(docker ps -aq)
if [ ! -z $res ]; then
    docker rm $res
fi

bash env_setup.sh

docker-compose build  $name
docker-compose up --remove-orphans --force-recreate -d $name
docker ps

echo "----- Logs so far ..-----"
echo "docker logs $(docker ps | tail -1 | cut -d " " -f 1)"
docker logs $(docker ps | tail -1 | cut -d " " -f 1)

#test
if [ $buildtype == "lambda" ]; then 
    echo "Pinging webserver endpoint: "
    payload='{"resource": "/", "path": "/", "httpMethod": "GET", "requestContext": {}, "multiValueQueryStringParameters": null}'
    curl "http://localhost:${port}/2015-03-31/functions/function/invocations" -d $payload
fi  

echo ""
