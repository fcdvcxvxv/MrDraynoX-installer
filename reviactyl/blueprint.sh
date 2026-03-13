export PTERODACTYL_DIRECTORY=/var/www/reviactyl
sudo apt install -y curl wget unzip
cd $PTERODACTYL_DIRECTORY
wget "$(curl -s https://api.github.com/repos/reviactyl/blueprint/releases/latest | grep 'browser_download_url' | grep 'release.zip' | cut -d '"' -f 4)" -O "$PTERODACTYL_DIRECTORY/release.zip"
unzip -o release.zip
# Install dependencies
sudo apt install -y ca-certificates curl git gnupg unzip wget zip

# Add Node.js apt repository
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
sudo apt update
sudo apt install -y nodejs

# cd into Pterodactyl, install yarn and node dependencies
cd $PTERODACTYL_DIRECTORY
npm i -g yarn
yarn install
touch $PTERODACTYL_DIRECTORY/.blueprintrc
# Writes data to your .blueprintrc file
echo \
'WEBUSER="www-data";
OWNERSHIP="www-data:www-data";
USERSHELL="/bin/bash";' > $PTERODACTYL_DIRECTORY/.blueprintrc
# Give blueprint.sh execute permissions
chmod +x $PTERODACTYL_DIRECTORY/blueprint.sh

# Run blueprint.sh
bash $PTERODACTYL_DIRECTORY/blueprint.sh
