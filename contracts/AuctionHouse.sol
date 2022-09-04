//SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "../interfaces/IERC721.sol";
import "../interfaces/IERC721Receiver.sol";

contract AuctionHouse is IERC721Receiver {
    struct Auction {
        bool auctionEnded;
        bytes32 auctionTitle;
        address nft;
        address payable beneficiary;
        address highestBidder;
        uint256 nftTokenId;
        uint256 auctionStartTime;
        uint256 auctionEndTime;
        uint256 highestBid;
    }

    uint256 public auctionId = 0;
    uint256 public commission = 5;
    address public owner;

    mapping(address => uint256) private balances;
    mapping(uint256 => Auction) public auctionIdToAuction;

    event AuctionCreated(
        uint256 auctionId,
        bytes32 auctionTitle,
        address nftContractAddress,
        uint256 nftId,
        address beneficiary
    );

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

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Not valid address");
        _;
    }

    function createAuction(
        uint256 _auctionDuration,
        bytes32 _auctionTitle,
        address _nftContractAddress,
        uint256 _nftTokenId
    ) external returns (bool success) {
        Auction memory auction = Auction(
            false,
            _auctionTitle,
            _nftContractAddress,
            payable(msg.sender),
            msg.sender,
            _nftTokenId,
            block.timestamp,
            block.timestamp + _auctionDuration,
            0
        );

        //Check if seller owns the NFT
        require(
            IERC721(_nftContractAddress).ownerOf(_nftTokenId) == msg.sender,
            "Seller does not own NFT"
        );
        IERC721(_nftContractAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _nftTokenId
        );
        //Check if NFT transfer was successful
        require(
            IERC721(_nftContractAddress).ownerOf(_nftTokenId) == address(this),
            "NFT transfer did not go through"
        );

        auctionIdToAuction[++auctionId] = auction; //Start with auction id 1, presumably ++i is more gas optimal then i++
        emit AuctionCreated(
            auctionId,
            _auctionTitle,
            _nftContractAddress,
            _nftTokenId,
            msg.sender
        );
        return true;
    }

    function bid() public view {}

    function endAuction(uint256 _auctionId) external {
        require(
            auctionIdToAuction[_auctionId].auctionEnded == false,
            "Auction is already closed."
        );
        require(
            auctionIdToAuction[_auctionId].auctionEndTime < block.timestamp,
            "It is not time yet to close auction"
        );

        IERC721 token = IERC721(auctionIdToAuction[_auctionId].nft);
        require(
            token.ownerOf(auctionIdToAuction[_auctionId].nftTokenId) ==
                address(this),
            "Auction does not own this nft"
        );
        auctionIdToAuction[_auctionId].auctionEnded = true;
        balances[
            auctionIdToAuction[_auctionId].highestBidder
        ] -= auctionIdToAuction[_auctionId].highestBid;
        balances[
            auctionIdToAuction[_auctionId].beneficiary
        ] += auctionIdToAuction[_auctionId].highestBid;

        //Complete changing all state variables before safeTransfer of nft to guard against reentrancy exploits.
        token.safeTransferFrom(
            address(this),
            auctionIdToAuction[_auctionId].highestBidder,
            auctionIdToAuction[_auctionId].nftTokenId
        );
    }

    function withdrawBalance() external payable {
        require(
            balances[msg.sender] > 0,
            "There is no ETH in corresponding balances to withdraw."
        );
        uint256 amount = balances[msg.sender];
        balances[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}(""); //Consider using call instead of transfer
        require(
            success,
            "There was some error with the withdraw transaction. It could not be completed."
        );
    }

    function setCommission(uint256 _newCommision) external onlyOwner {
        commission = (_newCommision > 8) ? 8 : _newCommision;
    }

    function changeOwner(address _newOwner)
        public
        onlyOwner
        validAddress(_newOwner)
    {
        owner = _newOwner;
    }

    function getBalance() external view returns (uint256 balance) {
        return balances[msg.sender];
    }

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(
        address,
        address,
        uint256 _tokenId,
        bytes memory
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {
        /**
         * @dev Make sure any eth sent to contract is receivable

         * In case any mistake is made while interacting with contract it will be deposited into msg.sender balance
         * which can be withdrawn later on too.
         */
        balances[msg.sender] += msg.value;
    }
}
