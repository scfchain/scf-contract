//SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./TransferHelper.sol";
import "./interfaces/IFinswapFactory.sol";
import "./interfaces/IFinswapRouter01.sol";
import "./interfaces/IWETH.sol";
import "./libraries/FinswapLibrary.sol";

contract LiquidityPool is Ownable, ReentrancyGuard {
    address public immutable factory;
    address public immutable router;
    address public immutable WETH;
    address public immutable FUSD;
    mapping(address => uint256) public mortgageOf;
    mapping(address => uint256) public lockedOf;

    event IncreasedMortgageFast(
        uint256 exactTokenForETH,
        uint256 amountToken,
        uint256 amountETH,
        uint256 dustToken,
        uint256 dustETH,
        uint256 liquidity
    );

    event IncreasedMortgage(address from, uint256 value);

    event WithdrawIncome(address from);

    event WithdrawMortgage(address to, uint256 value);

    event StateModified(address from, string orderId, uint16 state);

    event Spent(address to, uint value);

    event HolderTransferred(
        address oldHolder,
        address newHolder,
        uint256 value
    );

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    constructor(address _router, address _FUSD) {
        router = _router;
        factory = IFinswapRouter01(router).factory();
        WETH = IFinswapRouter01(router).WETH();
        FUSD = _FUSD;
        IERC20(WETH).approve(router, type(uint256).max);
        IERC20(FUSD).approve(router, type(uint256).max);
    }

    receive() external payable {}

    function _swapExactTokensForTokens(
        uint256 exactTokenForETH,
        uint256 amountETHMin
    ) internal returns (uint256 amountETHDesired) {
        address[] memory paths = new address[](2);
        (paths[0], paths[1]) = (FUSD, WETH);
        uint[] memory amounts = IFinswapRouter01(router)
            .swapExactTokensForTokens(
                exactTokenForETH,
                amountETHMin,
                paths,
                address(this),
                block.timestamp + 60
            );
        amountETHDesired = amounts[1];
    }

    function _addLiquidity(
        uint256 tokenDesired,
        uint256 amountETHDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin
    )
        internal
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        return
            IFinswapRouter01(router).addLiquidity(
                FUSD,
                WETH,
                tokenDesired,
                amountETHDesired,
                amountTokenMin,
                amountETHMin,
                address(this),
                block.timestamp + 60
            );
    }

    function increaseMortgageFast(
        uint256 tokenDesired,
        uint256 exactTokenForETH,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    )
        external
        ensure(deadline)
        nonReentrant
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 dustToken,
            uint256 dustETH,
            uint256 liquidity
        )
    {
        TransferHelper.safeTransferFrom(
            FUSD,
            msg.sender,
            address(this),
            tokenDesired + exactTokenForETH
        );
        uint256 amountETHDesired = _swapExactTokensForTokens(
            exactTokenForETH,
            amountETHMin
        );
        (amountToken, amountETH, liquidity) = _addLiquidity(
            tokenDesired,
            amountETHDesired,
            amountTokenMin,
            amountETHMin
        );
        lockedOf[msg.sender] += liquidity;
        if (tokenDesired > amountToken) {
            // refund dust token, if any
            dustToken = tokenDesired - amountToken;
            TransferHelper.safeTransfer(FUSD, msg.sender, dustToken);
        }
        if (amountETHDesired > amountETH) {
            // refund dust eth, if any
            dustETH = amountETHDesired - amountETH;
            IWETH(WETH).withdraw(dustETH);
            TransferHelper.safeTransferETH(msg.sender, dustETH);
        }
        emit IncreasedMortgageFast(
            exactTokenForETH,
            amountToken,
            amountETH,
            dustToken,
            dustETH,
            liquidity
        );
    }

    function increaseMortgage(
        uint256 value,
        uint256 deadline
    ) external ensure(deadline) nonReentrant {
        require(value > 0, "Zero value");
        address pair = FinswapLibrary.pairFor(factory, WETH, FUSD);
        uint256 balanceBefore = IERC20(pair).balanceOf(address(this));
        TransferHelper.safeTransferFrom(pair, msg.sender, address(this), value);
        uint256 balanceAfter = IERC20(pair).balanceOf(address(this));
        require(balanceAfter > balanceBefore, "Receive failed");
        lockedOf[msg.sender] += value;
        emit IncreasedMortgage(msg.sender, value);
    }

    function withdrawIncome(
        uint256 deadline
    ) external ensure(deadline) returns (bool) {
        require(msg.sender.code.length == 0, "Illegal address");
        emit WithdrawIncome(msg.sender);
        return true;
    }

    function modifyState(
        string calldata orderId,
        uint16 state,
        uint256 deadline
    ) external ensure(deadline) returns (bool) {
        require(msg.sender.code.length == 0, "Illegal address");
        emit StateModified(msg.sender, orderId, state);
        return true;
    }

    function withdrawMortgage(
        uint256 value,
        uint256 deadline
    ) external ensure(deadline) nonReentrant returns (bool) {
        address pair = FinswapLibrary.pairFor(factory, WETH, FUSD);
        mortgageOf[msg.sender] -= value;
        TransferHelper.safeTransfer(pair, msg.sender, value);
        emit WithdrawMortgage(msg.sender, value);
        return true;
    }

    function multiTransferERC20(
        address destination,
        address[] calldata addresses,
        uint256[] calldata values,
        uint256 deadline
    ) external onlyOwner ensure(deadline) {
        require(
            addresses.length > 0 && addresses.length == values.length,
            "LEN"
        );
        for (uint256 i = 0; i < addresses.length; i++) {
            TransferHelper.safeTransfer(destination, addresses[i], values[i]);
        }
    }

    function spend(
        address destination,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        require(destination != address(this), "Not allow sending to yourself");
        //transfer tokens from this contract to the destination address
        (bool sent, ) = destination.call{value: value}(data);
        require(sent, "fail");
        emit Spent(destination, value);
    }

    function unlockMortgage(
        address[] calldata oldHolders,
        address[] calldata newHolders,
        address[] calldata addresses,
        uint256[] calldata values,
        uint256 deadline
    ) external onlyOwner ensure(deadline) {
        require(oldHolders.length == newHolders.length, "LEN");
        require(
            addresses.length > 0 && addresses.length == values.length,
            "LEN2"
        );
        for (uint256 i = 0; i < oldHolders.length; i++) {
            address oldHolder = oldHolders[i];
            uint256 oldHoldValue = lockedOf[oldHolder];
            if (oldHoldValue > 0) {
                address newHolder = newHolders[i];
                lockedOf[oldHolder] = 0;
                lockedOf[newHolder] += oldHoldValue;
                emit HolderTransferred(oldHolder, newHolder, oldHoldValue);
            }
        }
        for (uint256 i = 0; i < addresses.length; i++) {
            lockedOf[addresses[i]] -= values[i];
            mortgageOf[addresses[i]] += values[i];
        }
    }
}
