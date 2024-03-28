#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 脚本保存路径
SCRIPT_PATH="$HOME/Alignedlayer.sh"

# 自动设置快捷键的功能
function check_and_set_alias() {
    local alias_name="Ali"
    local shell_rc="$HOME/.bashrc"

    # 对于Zsh用户，使用.zshrc
    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    # 检查快捷键是否已经设置
    if ! grep -q "$alias_name" "$shell_rc"; then
        echo "设置快捷键 '$alias_name' 到 $shell_rc"
        echo "alias $alias_name='bash $SCRIPT_PATH'" >> "$shell_rc"
        # 添加提醒用户激活快捷键的信息
        echo "快捷键 '$alias_name' 已设置。请运行 'source $shell_rc' 来激活快捷键，或重新打开终端。"
    else
        # 如果快捷键已经设置，提供一个提示信息
        echo "快捷键 '$alias_name' 已经设置在 $shell_rc。"
        echo "如果快捷键不起作用，请尝试运行 'source $shell_rc' 或重新打开终端。"
    fi
}

# 节点安装功能
function install_node() {

# 创建节点名称
read -p "输入节点名称,别搞奇形怪状的符号，纯英文就行: " MONIKER

sudo apt update && sudo apt upgrade -y

# 安装构建工具
sudo apt -qy install curl git jq lz4 build-essential

# 安装 Go
rm -rf $HOME/go
sudo rm -rf /usr/local/go
curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
source $HOME/.bash_profile
go version


# 克隆项目仓库
cd $HOME
rm -rf $HOME/aligned_layer_tendermint
git clone --depth 1 --branch v0.0.2 https://github.com/yetanotherco/aligned_layer_tendermint
cd $HOME/aligned_layer_tendermint/cmd/alignedlayerd 
go build 
chmod +x alignedlayerd
sudo mv alignedlayerd /usr/local/bin/


# 配置节点
alignedlayerd init $MONIKER --chain-id alignedlayer


# 安装创世文件
curl -Ls https://snap.nodex.one/alignedlayer-testnet/genesis.json > $HOME/.alignedlayer/config/genesis.json
curl -Ls https://snap.nodex.one/alignedlayer-testnet/addrbook.json > $HOME/.alignedlayer/config/addrbook.json 

# 设置种子节点和gas
sed -i -e "s|^seeds *=.*|seeds = \"d1d43cc7c7aef715957289fd96a114ecaa7ba756@testnet-seeds.nodex.one:24210\"|" $HOME/.alignedlayer/config/config.toml
sed -i -e 's|^persistent_peers *=.*|persistent_peers = "a1a98d9caf27c3363fab07a8e57ee0927d8c7eec@128.140.3.188:26656,1beca410dba8907a61552554b242b4200788201c@91.107.239.79:26656,f9000461b5f535f0c13a543898cc7ac1cd10f945@88.99.174.203:26656,ca2f644f3f47521ff8245f7a5183e9bbb762c09d@116.203.81.174:26656,dc2011a64fc5f888a3e575f84ecb680194307b56@148.251.235.130:20656,2f6456f1f2298def67dfccd9067e9b019798ba4d@62.171.130.196:24256"|' $HOME/.alignedlayer/config/config.toml
sed -i -e "s|^minimum-gas-prices *=.*|minimum-gas-prices = \"0.0001stake\"|" $HOME/.alignedlayer/config/app.toml



# 下载快照
curl -L https://snap.nodex.one/alignedlayer-testnet/alignedlayer-latest.tar.lz4 | tar -Ilz4 -xf - -C $HOME/.alignedlayer


# 设置启动服务
sudo tee /etc/systemd/system/alignedlayerd.service > /dev/null <<EOF
[Unit]
Description=alignedlayerd
After=network-online.target
[Service]
User=root
ExecStart=$(which alignedlayerd) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

cd $HOME
sudo systemctl daemon-reload
sudo systemctl enable alignedlayerd
sudo systemctl restart alignedlayerd

echo '====================== 安装完成 ==========================='
    
}

# 创建钱包
function add_wallet() {
    read -p "请输入钱包名称: " wallet_name
    alignedlayerd keys add "$wallet_name"
}

# 创建验证者
function add_validator() {
    pubkey=$(alignedlayerd comet show-validator)
    read -p "请输入您的钱包名称: " wallet_name
    read -p "请输入您想设置的验证者的名字: " validator_name
    read -p "请输入您的验证者详情（例如'吊毛资本'）: " details
    sudo tee ~/validator.json > /dev/null <<EOF
{
  "pubkey": ${PUBKEY},
  "amount": "1000000stake",
  "moniker": "$validator_name",
  "details": "$details",
  "commission-rate": "0.1",
  "commission-max-rate": "0.2",
  "commission-max-change-rate": "0.01",
  "min-self-delegation": "1"
}

EOF
wardend tx staking create-validator validator.json --from $wallet_name  \
--chain-id=alignedlayer \
--fees=50stake
--from=$wallet_name
}

# 导入钱包
function import_wallet() {
    read -p "请输入钱包名称: " wallet_name
    alignedlayerd keys add "$wallet_name" --recover
}

# 查询余额
function check_balances() {
    read -p "请输入钱包地址: " wallet_address
    alignedlayerd query bank balances "$wallet_address" 
}

# 查看节点同步状态
function check_sync_status() {
    alignedlayerd status | jq .sync_info
}

# 查看Alignedlayer 服务状态
function check_service_status() {
    systemctl status alignedlayerd
}

# 节点日志查询
function view_logs() {
    sudo journalctl -f -u alignedlayerd.service 
}

# 卸载节点功能
function uninstall_node() {
    echo "你确定要卸载Babylon 节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "开始卸载节点程序..."
            sudo systemctl stop alignedlayerd && sudo systemctl disable alignedlayerd && sudo rm /etc/systemd/system/alignedlayerd.service && sudo systemctl daemon-reload && rm -rf $HOME/.alignedlayerd && rm -rf alignedlayer && sudo rm -rf $(which alignedlayerd)

            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

function reward_test() {
echo "请进入网站:https://faucet.alignedlayer.com 领取测试代币"

}


# 主菜单
function main_menu() {
    while true; do
    clear
    echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，免费开源，请勿相信收费"
    echo "================================================================"
    echo "节点社区 Telegram 群组:https://t.me/niuwuriji"
    echo "节点社区 Telegram 频道:https://t.me/niuwuriji"
    echo "退出脚本，请按键盘ctrl c退出即可"
    echo "请选择要执行的操作:"
    echo "1. 安装节点"
    echo "2. 创建钱包"
    echo "3. 导入钱包"
    echo "4. 创建验证者"
    echo "5. 查看钱包地址余额"
    echo "6. 查看节点同步状态"
    echo "7. 查看当前服务状态"
    echo "8. 运行日志查询"
    echo "9. 卸载脚本"
    echo "10. 设置快捷键"  
    echo "11. 领水"  
    read -p "请输入选项（1-11）: " OPTION

    case $OPTION in
    1) install_node ;;
    2) add_wallet ;;
    3) import_wallet ;;
    4) add_validator ;;
    5) check_balances ;;
    6) check_sync_status ;;
    7) check_service_status ;;
    8) view_logs ;;
    9) uninstall_script ;;
    10) check_and_set_alias ;;  
    11) reward_test ;;  
    *) echo "无效选项。" ;;
    esac
    echo "按任意键返回主菜单..."
    read -n 1
done
}

# 显示主菜单
main_menu