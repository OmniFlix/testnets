#!/bin/sh
FLIX_HOME="/tmp/omniflixhub$(date +%s)"
RANDOM_KEY="random-validator-key"
CHAIN_ID=flixnet-1

GENTX_FILE=$(find ./$CHAIN_ID/gentxs -iname "*.json")
LEN_GENTX=$(echo ${#GENTX_FILE})

GENTX_DEADLINE=$(date -d '26-07-2021 18:00:00' '+%d/%m/%Y %H:%M:%S')
now=$(date +"%d/%m/%Y %H:%M:%S")

declare -i maxbond=50000000

if [ $now -ge $GENTX_DEADLINE ]; then
    echo 'Gentx submission is closed'
    exit 0
fi

if [ $LEN_GENTX -eq 0 ]; then
    echo "gentx file not found."
else
    set -e

    echo "GentxFile::::"
    echo $GENTX_FILE

    denom=$(jq -r '.body.messages[0].value.denom' $GENTX_FILE)

    amount=$(jq -r '.body.messages[0].value.amount' $GENTX_FILE)
    if [ $denom != "uflix" ]; then
        echo "invalid denom"
        exit 1
    fi

    if [ $amount -gt $maxbond ]; then
        echo "bonded amount is too high: $amt > $maxbond"
        exit 1
    fi

    echo "...........Init omniflixhub.............."

    git clone https://github.com/OmniFlix/omniflixhub
    cd omniflixhub
    git checkout v0.1.0
    make install

    omniflixhub keys add $RANDOM_KEY --home $FLIX_HOME

    omniflixhub init --chain-id $CHAIN_ID validator --home $FLIX_HOME

    echo "..........Updating genesis......."
    sed -i "s/\"stake\"/\"uflix\"/g" $FLIX_HOME/config/genesis.json

    GENACC=$(cat ../$GENTX_FILE | sed -n 's|.*"delegator_address":"\([^"]*\)".*|\1|p')

    echo $GENACC

    omniflixhub add-genesis-account $RANDOM_KEY 50000000uflix --home $FLIX_HOME --keyring-backend test
    omniflixhub add-genesis-account $GENACC 50000000uflix --home $FLIX_HOME

    omniflixhub gentx $RANDOM_KEY 40000000uflix --home $FLIX_HOME \
         --keyring-backend test --chain-id $CHAIN_ID
    cp ../$GENTX_FILE $FLIX_HOME/config/gentx/

    echo "..........Collecting gentxs......."
    omniflixhub collect-gentxs --home $FLIX_HOME
    sed -i '/persistent_peers =/c\persistent_peers = ""' $FLIX_HOME/config/config.toml

    omniflixhub validate-genesis --home $FLIX_HOME

    echo "..........Starting node......."
    omniflixhub start --home $FLIX_HOME &

    sleep 5s

    echo "...checking network status.."

    omniflixhubd status --node http://localhost:26657

    echo "...Cleaning ..."
    killall omniflixhub >/dev/null 2>&1
    rm -rf $FLIX_HOME >/dev/null 2>&1
fi
