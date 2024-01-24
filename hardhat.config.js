require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {version: "0.8.20", settings: {optimizer: {enabled: true, runs: 200}}}
    ],
    overrides: {}
  },
  defaultNetwork: "holesky",
  networks: {
    hardhat: {
    },
    mainnet: {
      chainId: 1,
      url: "https://api.chainup.net/ethereum/mainnet/ed670f52117b4eea8ccf9310b77ca0e5",
      accounts: [PRIVATE_KEY],
      maxPriorityFeePerGas: 20000000,
      maxFeePerGas:2000000000,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    },
    holesky: {
      chainId: 17000,
      url: "https://api.chainup.net/filecoin/mainnet/ed670f52117b4eea8ccf9310b77ca0e5",
      accounts: [PRIVATE_KEY],
      maxPriorityFeePerGas: 20000000,
      maxFeePerGas:2000000000,
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  },
  paths: {
    sources: "./src",
    tests: "./test/hardhat",
    cache: "./hardhat-cache",
    artifacts: "./artifacts"
  }
};
