#!/bin/sh
FLIX_HOME="/tmp/omniflixhub$(date +%s)"
RANDOM_KEY="random-validator-key"
CHAIN_ID=flixnet-1

GENTX_FILE=$(find ./$CHAIN_ID/gentxs -iname "*.json")
LEN_GENTX=$(echo ${#GENTX_FILE})

GENTX_DEADLINE=$(date -u -d '2021-07-26T18:00:00.000Z' +'%s')
now=$(date -u +'%s')

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

    wget -q https://github.com/OmniFlix/omniflixhub/releases/download/v0.1.0/omniflixhubd -O omniflixhubd
    chmod +x omniflixhubd
    
    ./omniflixhubd keys add $RANDOM_KEY --home $FLIX_HOME

    ./omniflixhubd init --chain-id $CHAIN_ID validator --home $FLIX_HOME

    echo "..........Updating genesis......."
    sed -i "s/\"stake\"/\"uflix\"/g" $FLIX_HOME/config/genesis.json

    GENACC=$(jq -r '.body.messages[0].delegator_address' $GENTX_FILE)

    echo $GENACC

    ./omniflixhubd add-genesis-account $RANDOM_KEY 50000000uflix --home $FLIX_HOME --keyring-backend test
    ./omniflixhubd add-genesis-account $GENACC 50000000uflix --home $FLIX_HOME

    ./omniflixhubd gentx $RANDOM_KEY 40000000uflix --home $FLIX_HOME \
         --keyring-backend test --chain-id $CHAIN_ID
    cp $GENTX_FILE $FLIX_HOME/config/gentx/

    echo "..........Collecting gentxs......."
    ./omniflixhubd collect-gentxs --home $FLIX_HOME
    sed -i '/persistent_peers =/c\persistent_peers = ""' $FLIX_HOME/config/config.toml

    ./omniflixhubd validate-genesis --home $FLIX_HOME

    echo "..........Starting node......."
    ./omniflixhubd start --home $FLIX_HOME &

    sleep 5s

    echo "...checking network status.."

    ./omniflixhubd status --node http://localhost:26657

    echo "...Cleaning ..."
    killall omniflixhubd >/dev/null 2>&1
    rm -rf $FLIX_HOME >/dev/null 2>&1
fi
