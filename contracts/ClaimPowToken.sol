pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./INekoProtocolToken.sol";
import "./IManekiNeko.sol";

contract ClaimPowToken is Context, AccessControlEnumerable, Initializable {

    uint8 public constant KIND_POW = 0;

    address public owner;
    address public deposit_address;

    INekoProtocolToken paymentToken;
    IManekiNeko manekineko;

    struct Claim {
        bytes32 _hashedMessage;
        uint256 claimId;
        uint256 value;
        address toAddress;
    }

    mapping(uint256 => Claim) public claimHistory;
    mapping(bytes32 => Claim) public hashClaim;
    bool public paused;

    event EventClaimPowToken(uint256 claimId, uint256 value, address to);
    event EventDepositPowToken(address depositFrom, address depositReceiveAddress, uint256 value);
    event EventMintReverse(uint timestamp, uint amount);

    function initialize(address _paymentToken, address _owner, address _deposit_address, address _manekineko)
    public
    initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        paymentToken = INekoProtocolToken(_paymentToken);
        owner = _owner;
        deposit_address = _deposit_address;
        manekineko = IManekiNeko(_manekineko);
    }

    function depositToken(uint256 _value) public {
        paymentToken.transferFrom(_msgSender(), deposit_address, _value);
        emit EventDepositPowToken(_msgSender(), deposit_address, _value);
    }

    function claimToken(
        bytes memory signature,
        uint256 _claimId,
        uint256 _value,
        uint256 _expTime
    ) public {
        bytes32 msgHash = keccak256(
            abi.encodePacked(_msgSender(), _claimId, _value, _expTime)
        );

        require(isSignatureValid(signature, msgHash, owner), "Invalid sign");

        require(hashClaim[msgHash].claimId == 0, "hash was exist");
        require(claimHistory[_claimId].claimId == 0, "claimId was exist");
        require(block.timestamp < _expTime, "claim token was end");

        require(!paused, "paused");

        Claim memory cl = Claim(msgHash, _claimId, _value, _msgSender());
        claimHistory[_claimId] = cl;
        hashClaim[msgHash] = cl;
        //Transfer
        // paymentToken.transfer(_msgSender(), _value);
        manekineko.claimTokenomic(KIND_POW, _msgSender(), _value);
        emit EventClaimPowToken(_claimId, _value, _msgSender());
    }

    function getRemainBalance() public view returns (uint256) {
        return paymentToken.balanceOf(address(this));
    }

    function setPause(bool _bool) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "must have admin role"
        );
        paused = _bool;
    }

    function isSignatureValid(
        bytes memory signature,
        bytes32 hash,
        address signer
    ) public pure returns (bool) {
        // verify hash signed via `personal_sign`
        return ECDSA.recover(ECDSA.toEthSignedMessageHash(hash), signature) == signer;
    }


    function setOwner(address newOwner) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "must have admin role"
        );
        owner = newOwner;
    }

    function setDepositAddress(address _deposit_address) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "must have admin role"
        );
        deposit_address = _deposit_address;
    }

    function getClaimById(uint256 _claimId) public view returns (Claim memory) {
        return claimHistory[_claimId];
    }
}
