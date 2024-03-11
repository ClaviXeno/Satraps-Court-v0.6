# Satraps Court Smart Contract

## Overview

The Satraps Court smart contract is a decentralized governance platform designed to facilitate voting and decision-making processes within a community. It allows participants to stake their tokens, cast votes, and mint statements or decrees based on the outcome of voting sessions.

## Features

- **Voting Sessions**: Conduct open, in-progress, and ended voting sessions.
- **Token Staking**: Stake tokens to gain voting power.
- **Vote Casting**: Cast votes on various options during voting sessions.
- **Statement/Decree Minting**: Mint statements or decrees based on voting outcomes.
- **Role-based Access Control**: Ensure secure access to administrative functions.

## Dependencies

- OpenZeppelin's ERC721 contract (`IERC721.sol`)
- OpenZeppelin's AccessControl contract (`AccessControl.sol`)
- OpenZeppelin's ERC721 interface contract (`IERC721.sol`)
- OpenZeppelin's ERC721 contract (`ERC721.sol`)
- OpenZeppelin's ERC721URIStorage contract (`ERC721URIStorage.sol`)
- OpenZeppelin's ERC721Enumerable contract (`ERC721Enumerable.sol`)
- OpenZeppelin's IERC721Receiver contract (`IERC721Receiver.sol`)

## Usage

1. **Setting up the Contract**: Deploy the smart contract with the appropriate dependencies and initialize the chairman.
2. **Managing Collections**: Add or remove collections for staking and voting.
3. **Starting Voting Sessions**: Start new voting sessions, add voting options, and finalize sessions.
4. **Staking Tokens**: Stake NFTs from accepted collections to gain voting power.
5. **Casting Votes**: Cast votes on available options during voting sessions.
6. **Minting Statements/Decrees**: Mint statements or decrees based on the outcome of voting sessions.
7. **Delegating Vote Power**: Delegate vote power to other participants.
8. **Granting OFFICER Role**: The chairman can grant the OFFICER role to other addresses after contract deployment, allowing them to perform administrative functions.
9. **Modular Upgradeability**: The contract is designed with modularity, enabling future upgrades and enhancements to all modules including the core contract.

## Minter Module Features and Usage

- **Setting Core Address**: Enables the chairman to set the address of the core contract.
- **Session Management**: Associates each minted token with a specific session ID.
- **ERC721 Compliance**: Implements ERC721, ERC721Enumerable, ERC721URIStorage standards for token management.
- **Security Checks**: Ensures that only authorized users (e.g., chairman, core contract) can perform minting and core contract setting operations.

1. **Setting Core Address**: Call the `setCore` function to set the address of the core contract.
2. **Session Management**: Retrieve session IDs associated with minted tokens using the `getSessionId` function.

## Notes

- Future upgrades of the contract should be deployed with session IDs starting from the last implementation's `currentSessionId + 1`.
- Historical session data can be sourced from older implementations for data retrieval and accessibility.

## License

This smart contract operates under the GNU LGPLv3 license.

## Author

- **Author**: Clavi

## Version Information

- **Version**: v0.6.0

## Repository Structure

- `contracts/` and `src/`: Contain the Solidity smart contract files.
- `README.md`: Provides an overview of the Satraps Court smart contract and Foundry setup.

## Contribution

Contributions to the development and improvement of the Satraps Court smart contract are welcome. Please submit pull requests or open issues for any suggestions or improvements.

## Support

For any questions, support, or inquiries, please contact the author or raise an issue in the GitHub repository.

## Acknowledgments

Special thanks to Thirdweb, Foundry, and OpenZeppelin for providing tools and foundational contracts used in this project.

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
