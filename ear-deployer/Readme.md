--- Docker Build and Publish

make release

-- Run the Docker command to deploy

sudo docker pull egovio/ear-deployer:latest

sudo docker run -it -v config/phoenix.yml:/phoenix.yml -e 'EAR_PASSCODE=${EAR_PASSCODE}' -e ENV=phoenix -e BUILDNUMBER=XXXX -e ENV_CONFIG_FILE=/phoenix.yml egovio/ear-deployer:latest
