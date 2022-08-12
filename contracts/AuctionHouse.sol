//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

contract AuctionHouse {
    struct Auction {
        bool auctionEnded;
        bytes32 auctionTitle;
        address nftContractAddress;
        address payable beneficiary;
        address highestBidder;
        uint256 nftTokenId;
        uint256 auctionStartTime;
        uint256 auctionEndTime;
        uint256 highestBid;
    }

    uint256 public auctionId = 0;
    uint256 public commission;
    address owner;

    mapping(address => uint256) private balances;
    mapping(uint256 => Auction) public auctionIdToAuction;

    event HighestBidIncreased(
        uint256 auctionId,
        bytes32 auctionTitle,
        address bidder,
        uint256 amount
    );

    event AuctionEnded(
        uint256 auctionId,
        bytes32 auctionTitle,
        address winner,
        uint256 winningBid
    );

    function createAuction(
        uint256 _auctionId,
        uint256 auctionDuration,
        bytes32 memory _auctionTitle,
        address _nftContractAddress,
        uint256 _nftTokenId
    ) external returns (bool success) {
        Auction public memory auction = Auction(
            false, 
            _auctionTitle, 
            _nftContractAddress,
            payable(msg.sender), 
            msg.sender,
            _nftTokenId,
            now,
            now + auctionDuration,
            0);

        auctionIdToAuction[auctionId] = auction;
        auctionId++;
        
    }

    function withdrawBalance() external payable { 
        require(
            balances[msg.sender] > 0,
            "There is no ETH in corresponding balances to withdraw."
        );
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).transfer(amount); //Consider using sendValue instead of transfer
        require(
            success,
            "There was some error with the withdraw transaction. It could not be completed."
        );
    }

    function getBalance() external view returns (uint256 balance) {
        return balances[msg.sender];
    }

    receive() external {
        /**
         * @dev Make sure any eth sent to contract is receivable

         * In case any mistake is made while interacting with contract it will be deposited into msg.sender balance
         * which can be withdrawn later on too.
         */
        balances[msg.sender] += msg.value;
    }
}
