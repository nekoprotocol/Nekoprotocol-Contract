// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IUniswapV2Router02.sol";
import "./IUniswapV2Factory.sol";
import "./IUniswapV2Pair.sol";

contract NekoProtocolToken is Ownable, ERC20 {
    using SafeMath for uint256;

    address public manekiNeko;

    uint256 public maxSupply = 34 *1e9 * 1e18;
    uint256 public initToken = 4319700000 * 1e18;
    
    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public treasuryAddress;
    uint256 public buyFee = 2;
    uint256 public sellFee = 3;
    bool inSwap = false;
    
    mapping(address => bool) public isExcludedFromFee;
    uint256 public checkBot = 10000000 * 1e18;
    uint256 public numTokensSellToAddToETH = 1500000 * 1e18;

    uint256 public blockBotDuration = 20;
    uint256 public blockBotTime;

    constructor(string memory name, string memory symbol, address _router) ERC20(name, symbol) {
        _mint(_msgSender(), initToken);
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
        treasuryAddress = _msgSender();
        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[treasuryAddress] = true;
    }

    modifier onlyManekiNeko() {
        require(_msgSender() == manekiNeko, "invalid manekiNeko");
        _;
    }

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    function setManekiNeko(address _manekiNeko) public onlyOwner {
        require(_manekiNeko != address(0), "0x is not accepted here");
        manekiNeko = _manekiNeko;
    }

    function beckon(address to, uint256 amount) external onlyManekiNeko {
        require(totalSupply() < maxSupply, "Over max supply");
        require(to != address(0), "0x is not accepted here");
        require(amount > 0, "not accept 0 value");

        if (maxSupply < totalSupply() + amount) {
            _mint(to, maxSupply - totalSupply());
        } else {
            _mint(to, amount);
        }
    }

    

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        uint256 transferFee;
        //check fee
        if(!isExcludedFromFee[sender] && recipient == uniswapV2Pair) {
            transferFee = sellFee;
        } else if(!isExcludedFromFee[recipient] && sender == uniswapV2Pair) {
            transferFee = buyFee;
        }

        //checkbot
        if (
            blockBotTime > block.timestamp &&
            amount > checkBot &&
            sender != address(this) &&
            recipient != address(this) &&
            sender == uniswapV2Pair
        ) {
            transferFee = 80;
        }

        //setup checkbot time
        if (blockBotTime == 0 && transferFee > 0 && amount > 0) {
            blockBotTime = block.timestamp + blockBotDuration;
        }

        if (inSwap) {
            super._transfer(sender, recipient, amount);
            return;
        }

        if (transferFee > 0 && sender != address(this) && recipient != address(this)) {
            uint256 _fee = amount.mul(transferFee).div(100);
            super._transfer(sender, address(this), _fee);
            amount = amount.sub(_fee);
        } else {
            callToTreasury();
        }

        super._transfer(sender, recipient, amount);
    }

    function callToTreasury() internal lockTheSwap {
        uint256 balanceThis = balanceOf(address(this));

        if (balanceThis > numTokensSellToAddToETH) {
            swapTokensForETH(balanceThis);
        }
    }

    function swapTokensForETH(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        uniswapV2Router.swapExactTokensForETH(tokenAmount, 0, path, treasuryAddress, block.timestamp);
    }

    function setExcludeFromFee(address _address, bool _status) external onlyOwner {
        require(_address != address(0), "0x is not accepted here");
        require(isExcludedFromFee[_address] != _status, "Status was set");
        isExcludedFromFee[_address] = _status;
    }

    function changeTreasuryWallet(address _treasuryWallet) external {
        require(_msgSender() == treasuryAddress, "Only TreasuryAddress Wallet!");
        require(_treasuryWallet != address(0), "0x is not accepted here");

        treasuryAddress = _treasuryWallet;
    }

    function changeNumTokensSellToAddToETH(uint256 _numTokensSellToAddToETH) external onlyOwner {
        require(_numTokensSellToAddToETH != 0, "_numTokensSellToAddToETH !=0");
        numTokensSellToAddToETH = _numTokensSellToAddToETH;
    }

    // receive eth
    receive() external payable {}

}
