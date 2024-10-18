interface IStakingFacet {
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward);

    function stakingEther(uint256 _durationInMinutes) external payable;
    function withdrawStakedEther(uint256 _amount) external;
    function calculateReward(address _user) external view returns (uint256);
    function myBalance() external view returns (uint256);
    function myBalanceAndReward() external view returns (uint256, uint256);
}