#!/bin/bash

BOLD=$(tput bold)
RESET=$(tput sgr0)
YELLOW=$(tput setaf 3)

print_command() {
  echo -e "${BOLD}${YELLOW}$1${RESET}"
}


print_command "Installing Cargo..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"

print_command "Installing NVM and Node..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash

export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"

if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
elif [ -s "/usr/local/share/nvm/nvm.sh" ]; then
    . "/usr/local/share/nvm/nvm.sh"
else
    echo "Error: nvm.sh not found!"
    exit 1
fi
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

print_command "Using Node version manager (nvm)..."
nvm install node
nvm use node

node -v
npm -v

print_command "Installing gblend tool..."
cargo install gblend

print_command "Running gblend..."
gblend --blendedapp

print_command "Installing dependencies (may take 2-3 mins)..."
npm install @nomicfoundation/hardhat-ethers@^3.0.7 @nomicfoundation/hardhat-toolbox@^5.0.0 @nomicfoundation/hardhat-verify@^2.0.0 @nomiclabs/hardhat-vyper@^3.0.7 @openzeppelin/contracts@^5.0.2 @typechain/ethers-v6@^0.5.0 @typechain/hardhat@^9.0.0 @types/node@^20.12.12 dotenv@^16.4.5 ethers@^6.13.2 hardhat@^2.22.4 hardhat-deploy@^0.12.4 ts-node@^10.9.2 typescript@^5.4.5

cat <<EOF > contracts/hello.sol
// SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;
    contract Hello {
        function main() public pure returns (string memory) {
            return "Hello, Solidity!";
        }
    }
EOF

rm -rf deploy
mkdir -p deploy
cat <<EOF > deploy/01_deploy_hello.ts
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    console.log("Deploying contracts with the account:", deployer);

    const token = await deploy("Hello", {
        from: deployer,
        log: true,
    });

    console.log("Hello contract deployed to:", token.address);
};

export default deployFunction;
deployFunction.tags = ["Hello"];
EOF

print_command "Removing hardhat.config.ts file..."
rm hardhat.config.ts

print_command "Updating hardhat.config.ts..."
cat <<EOF > hardhat.config.ts
import { HardhatUserConfig } from "hardhat/types";
import "@nomicfoundation/hardhat-ethers";
import "@nomiclabs/hardhat-vyper";
import "hardhat-deploy";
import dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  defaultNetwork: "fluent_devnet1",
  networks: {
    fluent_devnet1: {
      url: 'https://rpc.dev.thefluent.xyz/',
      chainId: 20993,
      accounts: [\0x\${process.env.DEPLOYER_PRIVATE_KEY}\],
    },
  },
  solidity: {
    version: '0.8.19',
  },
  vyper: {
    version: "0.3.0",
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;
EOF

read -p "Enter your EVM wallet private key (without 0x): " WALLET_PRIVATE_KEY

print_command "Generating .env file..."
cat <<EOF > .env
DEPLOYER_PRIVATE_KEY=$WALLET_PRIVATE_KEY
EOF

print_command "Compiling smart contracts..."
npx hardhat compile

print_command "Deploying smart contracts..."
npx hardhat deploy
