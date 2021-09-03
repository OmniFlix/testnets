#!/bin/bash

CHAIN_ID=flixnet-2
NODE_HOME=/tmp/ofhub
CONFIG=/tmp/ofhub/config

rm -rf $NODE_HOME

omniflixhubd init test --chain-id $CHAIN_ID --home $NODE_HOME

rm -rf $CONFIG/gentx && mkdir $CONFIG/gentx
rm -rf $CONFIG/genesis.json

cp $CHAIN_ID/genesis.json $CONFIG/genesis.json
for i in $CHAIN_ID/gentxs/*.json; do
  echo $i
  echo $(jq -r '.body.messages[0].delegator_address' $i)
  omniflixhubd add-genesis-account $(jq -r '.body.messages[0].delegator_address' $i) 100000000uflix --home $NODE_HOME
  cp $i $CONFIG/gentx/
done
echo "Collecting gentxs ..."
omniflixhubd collect-gentxs --home $NODE_HOME

echo "Validate genesis ..."
omniflixhubd validate-genesis --home $NODE_HOME

cp $CONFIG/genesis.json $CHAIN_ID
echo "Done. File saved at ${CHAIN_ID}/genesis.json"
