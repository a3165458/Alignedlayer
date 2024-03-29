wget -O Alignedlayer.sh https://raw.githubusercontent.com/a3165458/Alignedlayer/main/Alignedlayer.sh && chmod +x Alignedlayer.sh && ./Alignedlayer.sh

wget -O $HOME/.alignedlayer/config/addrbook.json https://raw.githubusercontent.com/a3165458/Alignedlayer/main/addrbook.json
sudo systemctl restart alignedlayerd
sudo journalctl -u alignedlayerd -f --no-hostname -o cat
