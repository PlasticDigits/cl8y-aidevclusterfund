// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title DonationMatchVault
 * @notice Holds USDT for matching donations and accumulates matched NFT donation notes
 * @dev Owned by CZodiac multisig
 */
contract DonationMatchVault is Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    // ============ Immutables ============
    
    IERC20 public immutable usdt;
    
    // ============ Events ============
    
    event Withdrawn(address indexed to, uint256 amount);
    event NFTReceived(address indexed operator, address indexed from, uint256 tokenId);
    
    // ============ Constructor ============
    
    /**
     * @param _owner The CZodiac multisig address
     * @param _usdt The USDT token address
     */
    constructor(address _owner, address _usdt) Ownable(_owner) {
        usdt = IERC20(_usdt);
    }
    
    // ============ Owner Functions ============
    
    /**
     * @notice Withdraw all USDT from the vault to the owner
     */
    function withdraw() external onlyOwner {
        uint256 balance = usdt.balanceOf(address(this));
        if (balance > 0) {
            usdt.safeTransfer(owner(), balance);
            emit Withdrawn(owner(), balance);
        }
    }
    
    /**
     * @notice Approve a spender to use vault's USDT (for DonationTranche matching)
     * @param spender The address to approve
     * @param amount The amount to approve
     */
    function approveUsdt(address spender, uint256 amount) external onlyOwner {
        usdt.approve(spender, amount);
    }
    
    // ============ View Functions ============
    
    /**
     * @notice Get current USDT balance available for matching
     */
    function getBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }
    
    // ============ ERC721 Receiver ============
    
    /**
     * @notice Handle receipt of NFT donation notes
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        emit NFTReceived(operator, from, tokenId);
        return this.onERC721Received.selector;
    }
}
