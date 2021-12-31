pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "./Recoverable.sol";

interface Minter {
    function mintToken(address owner) external;
}

contract ASPOStaking is Ownable, Recoverable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bool private _paused = false;
    bool private _stopped = false;
    address private _nftReward;

    address private _token;
    uint256 private _stakeAmount;
    uint256 private _stakeDuration;
    uint private _id;

    function _getId() private returns (uint) {
        return _id++;
    }

    struct Stake {
        uint256 id;
        address holder;
        uint256 startTime;
    }

    Stake[] private _stakes;

    event Staked(address token, uint id);
    event Rewarded(address token, uint id);
    event Canceled(address token, uint id);

    constructor (address token, uint256 stakeAmount, uint256 stakeDuration, address nftReward) {
        require(nftReward != address(0), "Invalid NFT reward address");
        require(stakeAmount > 0, "Stake amount must be greater than 0");
        require(stakeDuration > 0, "Stake duration must be greater than 0");

        _token = token;
        _nftReward = nftReward;
        _stakeAmount = stakeAmount * 10 ** 18;
        _stakeDuration = stakeDuration;
    }

    function token() public view returns (address){
        return _token;
    }

    function nftReward() public view returns (address){
        return _nftReward;
    }

    function stakeDuration() public view returns (uint256){
        return _stakeDuration;
    }

    function stakeAmount() public view returns (uint256){
        return _stakeAmount;
    }

    function paused() public view returns (bool){
        return _paused;
    }

    function pause() public onlyOwner {
        require(_paused == false, "Staking is paused");
        _paused = true;
    }

    function unpause() public onlyOwner {
        require(_paused == true, "Staking is not paused");
        _paused = false;
    }

    function stopped() public view returns (bool){
        return _stopped;
    }

    function stop() public onlyOwner {
        require(_stopped == false, "Staking is stopped");
        _stopped = true;
    }

    function myStakes() public view returns (Stake[] memory) {
        uint256 resultCount;
        for (uint i = 0; i < _stakes.length; i++) {
            if (_stakes[i].holder == msg.sender) {
                resultCount++;
            }
        }

        Stake[] memory results = new Stake[](resultCount);
        uint256 j;

        for (uint i = 0; i < _stakes.length; i++) {
            if (_stakes[i].holder == msg.sender) {
                results[j] = _stakes[i];
            }
        }
        return results;
    }

    function getStake(uint256 id) public view returns (Stake memory){
        for (uint i = 0; i < _stakes.length; i++) {
            if (_stakes[i].id == id) {
                return _stakes[i];
            }
        }
        revert('Not found'); 
    }

    function getStakes() public onlyOwner view returns (Stake[] memory){
        return _stakes;
    }

    function stake() payable public {
        require(_paused == false, "Staking is paused");
        require(_stopped == false, "Staking is stopped");
        IERC20(_token).transferFrom(msg.sender, address(this), _stakeAmount);
        Stake memory newStake;
        newStake.id = _getId();
        newStake.holder = msg.sender;
        newStake.startTime = block.timestamp;
        _stakes.push(newStake);

        emit Staked(newStake.holder, newStake.id);
    }

    function cancelStake(uint256 id) public onlyOwner {
        for (uint i = 0; i < _stakes.length; i++) {
            if (_stakes[i].id == id) {
                IERC20(_token).transfer(_stakes[i].holder, _stakeAmount);
                emit Canceled(_stakes[i].holder, _stakes[i].id);
                _stakes[i] = _stakes[_stakes.length-1];
                _stakes.pop();
                return;
            }
        }
        revert('Not found'); 
    }

    function rewardable(uint256 id) public view returns (bool){
        for (uint i = 0; i < _stakes.length; i++) {
            if (_stakes[i].id == id) {
                if(block.timestamp >= _stakes[i].startTime.add(_stakeDuration)){
                    return true;
                }
                return false;
            }
        }
        revert('Not found');
    }

    function reward(uint256 id) public {
        for (uint i = 0; i < _stakes.length; i++) {
            if (_stakes[i].id == id) {
                if(block.timestamp >= _stakes[i].startTime.add(_stakeDuration)){
                    IERC20(_token).transfer(_stakes[i].holder, _stakeAmount);
                    Minter(_nftReward).mintToken(_stakes[i].holder);
                    emit Rewarded(_stakes[i].holder, _stakes[i].id);
                    _stakes[i] = _stakes[_stakes.length-1];
                    _stakes.pop();
                    return;
                }
                revert('Need more time');
            }
        }
        revert('Not found');
    } 
}