// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";


/**
 * @title White list
 * @author Tanoshii_swap
 * @notice The assistance of DAO
 */
contract WhiteList is Ownable(msg.sender) {
  // use mapping, O(1)
  mapping(address => bool) whiteListed;
  address[] public  whiteLists;
  
  event WhiteAdded(address);
  event WhiteRemoved(address);

  error Unauthorized();
  error NotWhiteListed();

  /**
   * initial special address or not, 
   * we can use add method to add new address
   * @param specialAddress initial addresses
   */
  constructor(address[] memory specialAddress) {
    
    for(uint i = 0; i < specialAddress.length; i++) {
        address _address = specialAddress[i];
        if (_address != address(0) && !isExists(_address)) {
          whiteLists.push(_address);
          whiteListed[_address] = true;
        }  
    }
  }

  /**
   * add new address
   * @param _address new address
   * @dev Cannot add repeatedly
   */
  function add(address _address) public virtual onlyOwner {
    require(_address != address(0), "add: The invaliable address!");
    
    if (!isExists(_address)) {
        whiteLists.push(_address);
        whiteListed[_address] = true;
        
        emit WhiteAdded(_address);
    }
  }


  function remove(address _address) public virtual onlyOwner {
    require(isExists(_address), "remove: This address is not in whiteList");

    for (uint i = 0; i < whiteLists.length; i++) {
        if (whiteLists[i] == _address) {
            whiteLists[i] == whiteLists[whiteLists.length - 1];
            whiteLists.pop();
            whiteListed[_address] = false;
            break;
        }
    }
    
    emit WhiteRemoved(_address);
  }

  /**
   * Check if the address is exist
   * @param _address query address
   */
  function isExists(address _address) public view virtual returns(bool) {
    return whiteListed[_address];
  }

}