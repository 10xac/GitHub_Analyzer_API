#parameter
prof="--region us-east-1 --aws-profile kifiya"


stage=${1:-"dev"}
echo "=================================="
echo "Running for STAGE=$stage .."
echo "=================================="


if [ ! -d $stage ]; then
    echo "the staging parameter $stage does not have equivalent folder that contains serverless file!"
    exit
fi

echo "Deploying WITHOUT extension piece .."
cp $stage/serverless_step1.yml serverless.yml
sls deploy --stage $stage $prof --verbose

echo "Deploying WITH extension piece .."
cp $stage/serverless_step2.yml serverless.yml
sls deploy --stage $stage $prof

rm serverless.yml
