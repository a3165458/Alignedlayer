wget -O Alignedlayer.sh https://raw.githubusercontent.com/a3165458/Alignedlayer/main/Alignedlayer.sh && chmod +x Alignedlayer.sh && ./Alignedlayer.sh

curl -Ls https://raw.githubusercontent.com/a3165458/Alignedlayer/main/genesis.json > $HOME/.alignedlayer/config/genesis.json
curl -Ls https://raw.githubusercontent.com/a3165458/Alignedlayer/main/addrbook.json > $HOME/.alignedlayer/config/addrbook.json
