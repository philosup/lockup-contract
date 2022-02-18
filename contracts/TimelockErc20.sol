//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

//ERC20 토큰 전송시 해당 물량을 특정 기간동안 락업하는 기능을 추가한다.
//각 전송 마다 전송된 물량의 전부를 락업한다.(일부만 하는 기능이 필요한가?)

contract TimelockErc20 is ERC20, Ownable {
    struct LockInfo {
        uint256 amount;
        uint256 releaseTime;
    }

    mapping(address => LockInfo[]) public _lockInfo;

    function getLockedBalance(address _addr) public view returns (uint256) {
        uint256 totalLocked = 0;
        for (uint256 i = 0; i < _lockInfo[_addr].length; i++) {
            if (_lockInfo[_addr][i].releaseTime > block.timestamp) totalLocked += _lockInfo[_addr][i].amount;
        }
        return totalLocked;
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 amount
    ) ERC20(name, symbol) {
        _mint(_msgSender(), amount * 10**decimals());
    }

    //Don't accept ETH or BNB
    receive() external payable {
        revert("Don't accept ETH or BNB");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);

        uint256 locked = getLockedBalance(from);
        uint256 accountBalance = balanceOf(from);
        require(accountBalance - locked >= amount, "Timelock: some amount has locked.");
    }

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function transferWithLocked(
        address to,
        uint256 amount,
        uint256 releaseTime
    ) public returns (bool) {
        bool res = transfer(to, amount);
        if (res == false) return false;

        AddLockinfo(to, amount, releaseTime);

        return true;
    }

    function AddLockinfo(
        address to,
        uint256 amount,
        uint256 releaseTime
    ) internal {
        //remove released lockinfos
        uint256 lockCount = 0;
        for (uint256 i = 0; i < _lockInfo[to].length; i++) {
            if (_lockInfo[to][i].releaseTime > block.timestamp) {
                lockCount++;
            }
            if (i != lockCount) {
                _lockInfo[to][lockCount] = _lockInfo[to][i];
            }
        }

        uint256 removeCount = _lockInfo[to].length;
        if (lockCount == 0) delete _lockInfo[to];
        else {
            for (uint256 i = 0; i < removeCount; i++) _lockInfo[to].pop();
        }

        //add lockinfo if release time
        if (releaseTime > block.timestamp) _lockInfo[to].push(LockInfo(amount, releaseTime));
    }
}
