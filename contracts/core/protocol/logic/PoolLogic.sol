// SPDX-License-Identifier: agpl-3.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title  The pool core logic
 * @author Tanoshii_swap
 * when users supply liquidity,then return some LP Tokens(1:1)
 * use AMM 
 * users can:
 *  # supply
 *  # withdraw
 *  # 
 */

contract PoolLogic is ReentrancyGuard, Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC20 {

  using SafeERC20 for IERC20;

  IERC20 public token0; // LMAO
  IERC20 public token1; // ZETA
  
  uint256 public fee = 30; // fee / FEEBASE == 0.3%;
  uint256 private constant FEEBASE = 10000;
  uint256 private reserve0; // exp: LMAO
  uint256 private reserve1; // exp: ZETA
  uint256 private  blockTimestampLast;

  event Supply(
    address indexed  provider, 
    uint256 amountLMAO, 
    uint256 amountZETA, 
    uint256 LPToken
  );
  event Withdraw(
    address indexed  provider, 
    uint256 amountLMAO, 
    uint256 amountZETA, 
    uint256 LPToken
  );
  event Swapped(
    address indexed sender, 
    uint256 amountIn, 
    uint256 amountOut, 
    string direction
  );
  event Sync(
    uint256, 
    uint256
  );


  constructor(address _token0, address _token1) 
    ERC20("LP Token", "LLT") {
      token0 = IERC20(_token0);
      token1 = IERC20(_token1);
  }

  function initialize() public initializer {
    
     __Ownable_init(msg.sender);
    
  } 

  function supply(
    uint256 _amountToken0, 
    uint256 _amountToken1
    ) public virtual nonReentrant {
    require(_amountToken0 > 0 && _amountToken1 > 0, "addLiquidity: The Tokens Amounts Must Be Greater Than Zero");
    // 
    uint256 lpTokens;

    // first supply 
    if (totalSupply() == 0) {
      lpTokens = Math.sqrt(_amountToken0 * _amountToken1);
    } else {
      lpTokens = Math.min(_amountToken0 * totalSupply() / reserve0, (_amountToken1 * totalSupply()) / reserve1);
    }
    require(lpTokens > 0, "supply: lpTokens Must Be Greater Than Zero");

    token0.safeTransferFrom(msg.sender, address(this), _amountToken0);
    token1.safeTransferFrom(msg.sender, address(this), _amountToken1);

    // update reserves
    reserve0 += _amountToken0;
    reserve1 += _amountToken1;

    // mint Lp tokens
    _mint(msg.sender, lpTokens);

    _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)), block.timestamp);

    emit Supply(msg.sender, _amountToken0, _amountToken1, lpTokens);
  }


  /**
   * Withdraw according to the lpTokens
   * @param _lpTokens the lpTokens
   */
  function withdraw(
    uint256 _lpTokens
    ) public virtual nonReentrant {

    require(_lpTokens > 0 && _lpTokens <= balanceOf(msg.sender), "withdraw: Invalid LP Tokens");
    // 
    uint256 _totalSupply = totalSupply();
    uint256 amountToken0 = (_lpTokens * reserve0) / _totalSupply;
    uint256 amountToken1 =  (_lpTokens * reserve1) / _totalSupply;
    
    _burn(msg.sender, _lpTokens);

    // update reserve
    reserve0 -= amountToken0;
    reserve1 -= amountToken1;

    token0.safeTransfer( msg.sender, amountToken0);
    token1.safeTransfer( msg.sender, amountToken1);

    _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)), block.timestamp);

    emit Withdraw(msg.sender, amountToken0, amountToken1, _lpTokens);

  }


  /**
   * Swap can exchange token pairs, LMAO and ZETA
   * @param _reserveIn0 user deposit, should be LMAO 
   * @param _reserveIn1 user deposit, shoule be ZETA
   * @param minAmountOut prevent the sudden excessive slippage to protect the user's funds
   * 
   */
  function swap(
    uint256 _reserveIn0,
    uint256 _reserveIn1,
    uint256 minAmountOut
    // bytes calldata data
  ) public virtual nonReentrant {
    require(_reserveIn0 > 0 || _reserveIn1 > 0, "swap: Invalid Amount");

    (uint256 _reserve0, uint256 _reserve1,) = _getReserves();
    uint256 _fee;
    uint256 reserveOut;
    uint256 reserveIn;
    IERC20  tokenIn;
    IERC20  tokenOut;
    string memory swappedEventStr;

    // according to _amountIn0 == 0 or _amountIn1 == 0
    // if _amountIn0 > 0, then LMAO => ZETA
    // if _amountIn1 > 0, then ZETA => LMAO
    if (_reserveIn0 > 0) {
        reserveIn = _reserveIn0;
        _fee = (reserveIn * (FEEBASE - fee)) / FEEBASE;
        reserveOut = (_reserve1 * _fee) / (_reserve0 + _fee);
        swappedEventStr = "swap: Token0 => Token1";
        tokenIn = token0;
        tokenOut = token1;
    } else if (_reserveIn1 > 0) {
        reserveIn = _reserveIn1;
        _fee = (reserveIn * (FEEBASE - fee)) / FEEBASE;
        reserveOut = (_reserve0 * _fee) / (_reserve1 + _fee);
        swappedEventStr = "swap: Token1 => Token0";
        tokenIn = token1;
        tokenOut = token0; 
    }

    require(reserveOut >= minAmountOut, "swap: Slippage Too High");
        
    tokenIn.safeTransferFrom(msg.sender, address(this), reserveIn);
    tokenOut.safeTransfer(msg.sender, reserveOut);

    _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)), block.timestamp);
    emit Swapped(msg.sender, reserveIn, reserveOut, swappedEventStr);

  }


  /**
   * When process swap,change the pool
   * should update "reserve0" and "reserve1" by balance of the real assets
   * @param balance0 balance of one token, LMAO
   * @param balance1 balance of one token, ZETA
   * @param _blockTimestampLast the last update block timestamp
   */
  function _update(
    uint256 balance0, 
    uint256 balance1, 
    uint256 _blockTimestampLast
    ) private nonReentrant {
     require(balance0 >= 0 && balance1 >= 0, "_update: Invalid balance"); 
     reserve0 = balance0;
     reserve1 = balance1;
     blockTimestampLast = _blockTimestampLast;
     emit Sync(reserve0, reserve1);
  }

  /**
  * 
  * @return _reserve0 
  * @return _reserve1 
  * @return _blockTimestampLast 
  */
  function _getReserves() private view returns (uint256 _reserve0, uint256 _reserve1, uint256 _blockTimestampLast){
    _reserve0 = reserve0;
    _reserve1 = reserve1;
    _blockTimestampLast = blockTimestampLast;
  }
 
 /**
  * upGrade
  * @param newImplementation The new implementation address
  */
  function _authorizeUpgrade(address newImplementation) 
    internal 
    override 
    onlyOwner {

    }

  /**
   _contextSuffixLength() 
   _msgData()
   _msgSender() 
   Because of diamond inheritance
  */

  function _msgData() 
    internal 
    view 
    override(Context, ContextUpgradeable) 
    returns (bytes calldata) {
    return super._msgData();  
  }

  function _msgSender()
    internal
    view
    override(Context, ContextUpgradeable)
    returns (address) {
      return super._msgSender();
  }

  function _contextSuffixLength() 
    internal
    view
    override(Context, ContextUpgradeable)
    returns (uint256) {
      return super._contextSuffixLength();
  }

}