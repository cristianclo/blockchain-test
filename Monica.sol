// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts@5.4.0/token/ERC20/ERC20.sol";
import {ERC20Pausable} from "@openzeppelin/contracts@5.4.0/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts@5.4.0/access/Ownable.sol";

/// @custom:security-contact monica.galeendo@gmail.com
contract Monica is ERC20, ERC20Pausable, Ownable {

    // State variables
    address public treasury;
    uint256 public taxFee; // Fee in basis points (100 = 1%)
    
    // Maximum fee is 2% (200 basis points)
    uint256 public constant MAX_FEE = 200;
    
    // Mapping to track fee-exempt addresses
    mapping(address => bool) public isFeeExempt;

    // Events
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event TaxFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeExemptionUpdated(address indexed account, bool exempt);
    event TaxCollected(address indexed from, address indexed to, uint256 taxAmount, uint256 transferAmount);

    error InvalidTreasuryAddress();
    error InvalidTaxFee();
    error TransferFailed();


    constructor(
        string memory _name,
        string memory _symbol,
        address _treasury,
        uint256 _taxFee)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        if (_treasury == address(0)) revert InvalidTreasuryAddress();
        if (_taxFee > MAX_FEE) revert InvalidTaxFee();
        treasury = _treasury;
        taxFee = _taxFee;
        
        // Owner and treasury are fee exempt by default
        isFeeExempt[msg.sender] = true;
        isFeeExempt[_treasury] = true;
        
        // Mint initial supply to deployer (optional - adjust as needed)
        _mint(msg.sender, 1000000 * 10**decimals());
        
        emit TreasuryUpdated(address(0), _treasury);
        emit TaxFeeUpdated(0, _taxFee);
        emit FeeExemptionUpdated(msg.sender, true);
        emit FeeExemptionUpdated(_treasury, true);
    }

    /**
     * @dev Updates the treasury address
     * @param _newTreasury New treasury address
     */
    function setTreasury(address _newTreasury) external onlyOwner {
        if (_newTreasury == address(0)) revert InvalidTreasuryAddress();
        
        address oldTreasury = treasury;
        treasury = _newTreasury;
        
        // Update fee exemption
        isFeeExempt[oldTreasury] = false;
        isFeeExempt[_newTreasury] = true;
        
        emit TreasuryUpdated(oldTreasury, _newTreasury);
        emit FeeExemptionUpdated(oldTreasury, false);
        emit FeeExemptionUpdated(_newTreasury, true);
    }
    
    /**
     * @dev Updates the tax fee
     * @param _newFee New tax fee in basis points
     */
    function setTaxFee(uint256 _newFee) external onlyOwner {
        if (_newFee > 10000) revert InvalidTaxFee();
        
        uint256 oldFee = taxFee;
        taxFee = _newFee;
        
        emit TaxFeeUpdated(oldFee, _newFee);
    }
    
    /**
     * @dev Sets fee exemption status for an address
     * @param _account Address to update
     * @param _exempt Whether the address should be exempt from fees
     */
    function setFeeExemption(address _account, bool _exempt) external onlyOwner {
        isFeeExempt[_account] = _exempt;
        emit FeeExemptionUpdated(_account, _exempt);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Override transfer to include tax logic
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _update(owner, to, amount);
        return true;
    }
    
    /**
     * @dev Override transferFrom to include tax logic
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _update(from, to, amount);
        return true;
    }
    
    /**
     * @dev Returns the maximum fee that can be set
     */
    function getMaxFee() external pure returns (uint256) {
        return MAX_FEE;
    }
    
    /**
     * @dev Returns the current tax fee as a percentage (with 2 decimals)
     */
    function getTaxFeePercentage() external view returns (uint256) {
        return taxFee;
    }
    
    /**
     * @dev Calculates tax amount for a given transfer amount
     * @param amount Transfer amount
     * @return Tax amount that would be collected
     */
    function calculateTax(uint256 amount) external view returns (uint256) {
        return (amount * taxFee) / MAX_FEE;
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Pausable) {
        if (from != address(0) && to != address(0)) {
            if (taxFee > 0) {
                uint256 fee = (amount * taxFee) / 100;
                if (fee > 0) {
                    super._update(from, treasury, fee);
                    uint256 net = amount - fee;
                    super._update(from, to, net);
                    return;
                }
            }
        }
        super._update(from, to, amount);
    }
}
