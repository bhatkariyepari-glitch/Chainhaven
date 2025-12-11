// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ChainHaven
 * @notice A secure asset vault with guardian-based protection and emergency controls.
 */

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract ChainHaven {
    struct Vault {
        uint256 ethBalance;
        mapping(address => uint256) tokenBalance;
        address guardian;
        bool locked;
    }

    struct Activity {
        address user;
        string action;
        address token;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Vault) private vaults;
    mapping(address => Activity[]) private activityLog;

    event Deposited(address indexed user, address token, uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, address token, uint256 amount, uint256 timestamp);
    event GuardianAssigned(address indexed user, address guardian);
    event GuardianRemoved(address indexed user);
    event VaultLocked(address indexed user, address guardian);
    event VaultUnlocked(address indexed user);

    modifier notLocked(address user) {
        require(!vaults[user].locked, "Vault is locked");
        _;
    }

    // ─────────────────────────────────────────────
    // ⭐ ASSIGN / REMOVE GUARDIAN
    // ─────────────────────────────────────────────
    function assignGuardian(address guardian) external {
        require(guardian != msg.sender, "Cannot assign self");
        vaults[msg.sender].guardian = guardian;

        emit GuardianAssigned(msg.sender, guardian);
    }

    function removeGuardian() external {
        vaults[msg.sender].guardian = address(0);

        emit GuardianRemoved(msg.sender);
    }

    // ─────────────────────────────────────────────
    // ⭐ EMERGENCY GUARDIAN LOCK
    // ─────────────────────────────────────────────
    function lockVault(address user) external {
        require(vaults[user].guardian == msg.sender, "Not guardian");
        vaults[user].locked = true;

        emit VaultLocked(user, msg.sender);
    }

    function unlockVault() external {
        require(vaults[msg.sender].locked, "Not locked");
        vaults[msg.sender].locked = false;

        emit VaultUnlocked(msg.sender);
    }

    // ─────────────────────────────────────────────
    // ⭐ DEPOSIT ETH
    // ─────────────────────────────────────────────
    function depositETH() external payable notLocked(msg.sender) {
        require(msg.value > 0, "No ETH sent");

        vaults[msg.sender].ethBalance += msg.value;
        _log(msg.sender, "Deposit ETH", address(0), msg.value);

        emit Deposited(msg.sender, address(0), msg.value, block.timestamp);
    }

    // ─────────────────────────────────────────────
    // ⭐ WITHDRAW ETH
    // ─────────────────────────────────────────────
    function withdrawETH(uint256 amount) external notLocked(msg.sender) {
        require(amount > 0, "Invalid amount");
        require(vaults[msg.sender].ethBalance >= amount, "Insufficient balance");

        vaults[msg.sender].ethBalance -= amount;
        payable(msg.sender).transfer(amount);

        _log(msg.sender, "Withdraw ETH", address(0), amount);
        emit Withdrawn(msg.sender, address(0), amount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    // ⭐ DEPOSIT ERC20 TOKENS
    // ─────────────────────────────────────────────
    function depositToken(address token, uint256 amount) external notLocked(msg.sender) {
        require(amount > 0, "Amount required");

        IERC20(token).transferFrom(msg.sender, address(this), amount);
        vaults[msg.sender].tokenBalance[token] += amount;

        _log(msg.sender, "Deposit Token", token, amount);
        emit Deposited(msg.sender, token, amount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    // ⭐ WITHDRAW ERC20 TOKENS
    // ─────────────────────────────────────────────
    function withdrawToken(address token, uint256 amount) external notLocked(msg.sender) {
        require(amount > 0, "Invalid amount");
        require(vaults[msg.sender].tokenBalance[token] >= amount, "Insufficient balance");

        vaults[msg.sender].tokenBalance[token] -= amount;
        IERC20(token).transfer(msg.sender, amount);

        _log(msg.sender, "Withdraw Token", token, amount);
        emit Withdrawn(msg.sender, token, amount, block.timestamp);
    }

    // ─────────────────────────────────────────────
    // ⭐ VIEW FUNCTIONS
    // ─────────────────────────────────────────────
    function getEthBalance(address user) external view returns (uint256) {
        return vaults[user].ethBalance;
    }

    function getTokenBalance(address user, address token) external view returns (uint256) {
        return vaults[user].tokenBalance[token];
    }

    function getGuardian(address user) external view returns (address) {
        return vaults[user].guardian;
    }

    function isLocked(address user) external view returns (bool) {
        return vaults[user].locked;
    }

    function getActivityLog(address user) external view returns (Activity[] memory) {
        return activityLog[user];
    }

    // ─────────────────────────────────────────────
    // ⭐ INTERNAL EVENT LOGGING
    // ─────────────────────────────────────────────
    function _log(address user, string memory action, address token, uint256 amount) internal {
        activityLog[user].push(
            Activity(user, action, token, amount, block.timestamp)
        );
    }
}
