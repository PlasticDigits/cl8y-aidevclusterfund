// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDT
 * @notice Mock USDT token for local testing with Anvil
 * @dev Mintable by anyone - DO NOT use in production
 */
contract MockUSDT is ERC20 {
    constructor() ERC20("Tether USD", "USDT") {}

    /**
     * @notice Mint tokens to any address
     * @param to Recipient address
     * @param amount Amount to mint (18 decimals)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Returns 18 decimals (BSC USDT standard)
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}
