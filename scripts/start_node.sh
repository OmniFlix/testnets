#!/bin/bash

NODE_HOME=~/.omniflixhub
NODE_MONIKER="myflixnode"
CHAIN_ID="flixnet-2"
SERVICE_NAME="omniflixhubd"

is_exists () {
    type "$1" &> /dev/null ;
}
is_service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}
echo "Step1 - Installing go lang ..."
if is_exists go; then
    echo "Go lang is already installed ...";
else
    #sudo rm -rf /usr/local/go
    curl https://dl.google.com/go/go1.16.5.linux-amd64.tar.gz | sudo tar -C /usr/local -zxvf -
   
    echo "" > ~/.profile
    echo 'export GOROOT=/usr/local/go' > ~/.profile
    echo 'export GOPATH=$HOME/go' > ~/.profile
    echo 'export GO111MODULE=on' > ~/.profile
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' > ~/.profile
    source ~/.profile

    echo "go lang Installed ..."
    go version
fi

echo "Step2 - Installing omniflixhubd ..."
if is_exists omniflixhubd; then
    echo "omniflixhub is already installed ..."
    omniflixhubd version
else
    echo "Installing omniflixhub"
    sleep 2
    sudo apt-get install git curl build-essential make jq -y
    git clone https://github.com/Omniflix/omniflixhub.git
    cd omniflixhub
    git checkout v0.2.1
    make install
    
    echo "omniflixhub installed ..."
    omniflixhubd version --long
fi
echo "Step3 - Initializing node ..."
if [ -d "${NODE_HOME}/config" ]; then
    echo "node already initialized ..."
    echo "Node ID:"
    omniflixhubd tendermint show-node-id --home $NODE_HOME
else
    echo "Initializing node ..."
    sleep 2;
    omniflixhubd init $NODE_MONIKER --chain-id $CHAIN_ID --home $NODE_HOME
    echo "Done .."
fi
echo "Step4 - Downloading genesis ..."
curl -s https://raw.githubusercontent.com/OmniFlix/testnets/main/$CHAIN_ID/genesis.json > $NODE_HOME/config/genesis.json
echo "genesis file sha256 hash"
shasum -a 256 $NODE_HOME/config/genesis.json

echo "Step5 - Updating seeds and peers .."
seeds=$(curl https://raw.githubusercontent.com/OmniFlix/testnets/main/$CHAIN_ID/seed_nodes.txt -s |  xargs | sed -e 's/ /,/g')
peers=$(curl https://raw.githubusercontent.com/OmniFlix/testnets/main/$CHAIN_ID/persistent_peers.txt -s |  xargs | sed -e 's/ /,/g')

sed -i.bak -e "s/^seeds *=.*/seeds = \"$seeds\"/; s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $NODE_HOME/config/config.toml
echo "Done .."

echo "Step6 - Starting node ..."
if is_service_exists $SERVICE_NAME; then
    echo "${SERVICE_NAME} service already exists ..."
else  
    echo "[Unit]
Description=OmniFlixHub Daemon
After=network-online.target

[Service]
User=${USER}
ExecStart=$(which omniflixhubd) start --home $NODE_HOME
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target" > omniflixhubd.service
    sudo mv omniflixhubd.service /etc/systemd/system/omniflixhubd.service
    sudo systemctl daemon-reload
    sudo systemctl enable omniflixhubd
fi

sudo systemctl restart omniflixhubd
sleep 5
echo "Done .."

echo "Step7 - Checking service logs"
journalctl -eu omniflixhubd.service --no-pager
echo "Completed.."
