// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title pool proxy
 * @author Tanoshii_swap
 * 
 */
contract poolProxy is ERC1967Proxy {
  
  constructor(
    address _logic,
    bytes memory _data
  ) ERC1967Proxy(
    _logic,
    _data
  ) {}

}