import glob
import json


CHAIN_ID = 'flixnet-2'
PREV_CHAIN_ID = 'flixnet-1'
gentx_files = glob.glob(f'./{CHAIN_ID}/gentxs/*.json')

if len(gentx_files) != 1:
    print("invalid submission!!")
    exit(1)

gentx_file = gentx_files[0]

with open(gentx_file, 'r') as f:
    gentx = json.loads(f.read())


p_file = f'./{PREV_CHAIN_ID}/validator_addresses.txt'
with open(p_file, 'r') as p_f:
    text = p_f.read()
    prev_participants = text.strip().split('\n')

if gentx['body']['messages'][0]['validator_address'] in prev_participants:
    print("Yes, Previous Participant")
else:
    print('No')


