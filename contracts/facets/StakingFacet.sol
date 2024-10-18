import {LibDiamond} from "../libraries/LibDiamond.sol";

contract StakingFacet {
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    function stakingEther(uint256 _durationInMinutes) external payable {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(msg.sender != address(0), "Address zero detected");
        require(msg.value > 0, "Can't deposit zero into the pool");
        require(_durationInMinutes > 0, "Duration can't be set to zero");

        LibDiamond.Users storage user = ds.users[msg.sender];
        require(user.amount == 0, "You can only stake once");

        uint256 durationInSeconds = _durationInMinutes * 60;

        user.user = msg.sender;
        user.amount = msg.value;
        user.duration = block.timestamp + durationInSeconds;
        user.isDone = false;

        ds.stakebalances[msg.sender] += msg.value;

        emit Staked(msg.sender, msg.value, user.duration);
    }

    function withdrawStakedEther(uint256 _amount) external {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        require(_amount > 0, "Can't withdraw zero");

        LibDiamond.Users storage user = ds.users[msg.sender];
        require(block.timestamp >= user.duration, "Staking period not completed");
        require(!user.isDone, "Ether already withdrawn");
        require(user.amount >= _amount, "Insufficient staked amount");

        uint256 reward = calculateReward(msg.sender);

        uint256 totalAmount = _amount + (reward * _amount / user.amount);
        require(ds.stakebalances[address(this)] >= totalAmount, "Insufficient reward pool");

        user.amount -= _amount;
        if (user.amount == 0) {
            user.isDone = true;
        }
        ds.stakebalances[address(this)] -= totalAmount;

        (bool sent, ) = msg.sender.call{value: totalAmount}("");
        require(sent, "Failed to withdraw Ether");

        emit Withdrawn(msg.sender, _amount, reward * _amount / user.amount);
    }

    function calculateReward(address _user) public view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.Users memory user = ds.users[_user];

        uint256 duration = block.timestamp - user.duration;
        uint256 reward = (user.amount * duration * 10) / (365 * 1440 * 100);

        return reward;
    }

    function myBalance() external view returns (uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        return ds.users[msg.sender].amount;
    }

    function myBalanceAndReward() external view returns (uint256, uint256) {
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        LibDiamond.Users memory user = ds.users[msg.sender];
        uint256 reward = calculateReward(msg.sender);
        return (user.amount, reward);
    }
}