require("@nomicfoundation/hardhat-toolbox");
require("hardhat-deploy")
require("dotenv").config()

/** @type import('hardhat/config').HardhatUserConfig */

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x"

module.exports = {
  solidity: "0.8.20",
  networks: {
    hardhat: {
        chainId: 31337,
    },
    localhost: {
        chainId: 31337,
    },
    alfajores: {
        url: "https://alfajores-forno.celo-testnet.org",
        accounts: [PRIVATE_KEY],
        chainId: 44787
      },
      celo: {
      url:  "https://forno.celo.org",
      accounts: [PRIVATE_KEY],
      chainId: 42220
    }
},
namedAccounts: {
  deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
  },

},


};
