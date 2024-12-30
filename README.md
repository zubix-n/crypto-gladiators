# CryptoGladiators

CryptoGladiators is a blockchain-based character collection and battle system built on the Stacks blockchain. Players can mint unique characters, train them through battles, and trade them in an open marketplace.

## Overview

CryptoGladiators combines collectible NFT mechanics with battle gameplay, where each character has unique stats and can level up through combat. The game features:

- Character minting with random initial stats
- Character battles with experience and leveling
- Open marketplace for trading characters
- Progressive stat improvements

## Game Mechanics

### Characters

Each character has the following attributes:
- Level (1-100)
- Attack Power
- Defense Power
- Experience Points
- Battle Cooldown Timer

### Battles

- Characters can battle each other for rewards
- Winner is determined by comparing attack vs defense power
- Winners gain 50 XP
- Losers gain 25 XP
- 10 block cooldown between battles

### Leveling System

- Characters need increasing XP to level up
- Each level up increases:
  - Attack Power (+1)
  - Defense Power (+1)
- Maximum level is 100

### Marketplace

- Players can list characters for sale
- Minimum listing price: 1,000 microSTX
- Ownership transfers upon successful purchase

## Contract Functions

### Character Management
```clarity
(mint-character (name (string-ascii 24)))
```
- Mints a new character with random stats
- Cost: 100,000 microSTX

### Market Operations
```clarity
(list-for-sale (character-id uint) (price uint))
(buy-character (character-id uint))
```
- List and buy characters from the marketplace

### Battle System
```clarity
(battle (attacker-id uint) (defender-id uint))
```
- Initiate battles between characters

### Read-Only Functions
```clarity
(get-character (character-id uint))
(get-listing (character-id uint))
(get-owner-count (user principal))
```
- Query character and market information

## Limitations

- Maximum 100 characters per user
- 10 block cooldown between battles
- Character names limited to 24 ASCII characters
- Minimum listing price of 1,000 microSTX

## Getting Started

1. Deploy the contract to the Stacks blockchain
2. Mint your first character using `mint-character`
3. Battle other characters to gain experience
4. Trade characters in the marketplace

## Security Features

- Input validation for all public functions
- Ownership verification for actions
- Battle cooldown system
- Safe transfer handling
- Character limit per user

## Development

The contract is developed in Clarity and follows a modular structure with:
1. Basic data structures
2. Character creation system
3. Market system
4. Battle mechanics
5. Experience/leveling system
6. Input validation

## Testing

Use Clarinet to run the test suite:
```bash
clarinet test
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## License

MIT License