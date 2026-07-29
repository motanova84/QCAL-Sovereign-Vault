require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x0000000000000000000000000000000000000000000000000000000000000001";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const ALCHEMY_SEPOLIA_URL = process.env.ALCHEMY_SEPOLIA_URL || "https://rpc.sepolia.org";
const BASE_SEPOLIA_URL = process.env.BASE_SEPOLIA_URL || "https://sepolia.base.org";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.24",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            viaIR: true,
            evmVersion: "cancun",
        },
    },

    defaultNetwork: "hardhat",

    networks: {
        hardhat: {
            chainId: 31337,
            mining: {
                auto: true,
                interval: 0,
            },
        },
        localhost: {
            url: "http://127.0.0.1:8545",
            chainId: 31337,
        },
        sepolia: {
            url: ALCHEMY_SEPOLIA_URL,
            accounts: [PRIVATE_KEY],
            chainId: 11155111,
            gasPrice: "auto",
        },
        baseSepolia: {
            url: BASE_SEPOLIA_URL,
            accounts: [PRIVATE_KEY],
            chainId: 84532,
            gasPrice: "auto",
        },
    },

    etherscan: {
        apiKey: {
            sepolia: ETHERSCAN_API_KEY,
            baseSepolia: process.env.BASESCAN_API_KEY || ETHERSCAN_API_KEY,
        },
        customChains: [
            {
                network: "baseSepolia",
                chainId: 84532,
                urls: {
                    apiURL: "https://api-sepolia.basescan.org/api",
                    browserURL: "https://sepolia.basescan.org",
                },
            },
        ],
    },

    paths: {
        sources: "./contracts",
        tests: "./tests",
        cache: "./cache",
        artifacts: "./artifacts",
    },

    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: "USD",
    },
};
