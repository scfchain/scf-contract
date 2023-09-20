pragma solidity >=0.5.16;

import './interfaces/IFinswapFactory.sol';
import './FinswapPair.sol';

contract FinswapFactory is IFinswapFactory {
    address public feeTo;
    address public feeToSetter;
    uint256 public feeToRate = 0;

    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(FinswapPair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external returns (address pair) {
        require(tokenA != tokenB, 'Finswap: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'Finswap: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'Finswap: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(FinswapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IFinswapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'Finswap: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'Finswap: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function setFeeToRate(uint256 _rate) external {
        require(msg.sender == feeToSetter, 'SwapFactory: FORBIDDEN');
        require(_rate > 0, 'SwapFactory: FEE_TO_RATE_OVERFLOW');
        feeToRate = _rate - 1;
    }
}
