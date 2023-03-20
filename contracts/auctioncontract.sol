// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "../lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Auction is Ownable {
    address[] public admins;
    uint256 public auctionId = 1;
    mapping(address => uint) public bids;
    address _owner;

    struct AuctionItem {
        string name;
        address nftAddress;
        uint256 nftId;
        address Creator;
        uint256 duration;
        bool auctionStarted;
        uint256 highestBid;
        uint256[] Bids;
        address highestbidder;
        uint256 startingPrice;
        mapping(address => uint256) bidders;
    }
    mapping(uint256 => AuctionItem) public auctionItems;

    modifier onlyAdmin() {
        bool isAdmin = false;
        for (uint i = 0; i < admins.length; i++) {
            if (admins[i] == msg.sender) {
                isAdmin = true;
                break;
            }
        }
        require(isAdmin, "Only admins");
        _;
    }

    constructor() {
        admins.push(msg.sender);
        _owner = msg.sender;
    }

    function addAdmin(address _admin) public onlyAdmin {
        admins.push(_admin);
    }

    function removeAdmin(address _admin) public onlyOwner {
        for (uint i = 0; i < admins.length; i++) {
            if (admins[i] == _admin) {
                delete admins[i];
                break;
            }
        }
    }

    function startAuction(
        string memory _itemName,
        address _nftAddress,
        uint256 _nftId,
        uint256 _duration,
        uint256 _startingprice,
        address _nftOwner
    ) public onlyAdmin {
        AuctionItem storage newItem = auctionItems[auctionId];
        newItem.name = _itemName;
        newItem.nftAddress = _nftAddress;
        newItem.nftId = _nftId;
        newItem.Creator = msg.sender;
        newItem.duration = _duration;
        require(_duration > block.timestamp, "invalid time");
        newItem.auctionStarted = true;
        newItem.highestBid = 0;
        newItem.startingPrice = _startingprice;
        IERC721(newItem.nftAddress).safeTransferFrom(
            _nftOwner,
            address(this),
            newItem.nftId
        );

        if (block.timestamp == _duration) {
            endAuction(newItem.nftId);
        }
        newItem.bidders[_nftOwner] = _startingprice;
        if (newItem.duration == block.timestamp) {
            endAuction(_nftId);
        }
        auctionId += 1;
    }

    function placeBid(uint256 _auctionId) public payable {
        AuctionItem storage item = auctionItems[_auctionId];
        require(item.auctionStarted, "auction not started");

        require(msg.value > item.startingPrice);

        item.bidders[msg.sender] = msg.value;
        item.Bids.push(msg.value);
        // item.getbidders[msg.value] = msg.sender;
        if (msg.sender != address(0) && msg.value > item.highestBid) {
            item.highestBid = msg.value;
            item.highestbidder = msg.sender;
        }
        //    (bool success, ) = msg.sender.call{value: msg.value}("");
        //     require(success, "failed to pay price");
    }

     function updatebBid(uint _id) public payable {
        AuctionItem storage auction = auctionItems[_id];
        uint previous_bid = auction.bidders[msg.sender];

        if (auction.auctionStarted) revert ("can't update bid");
        if (previous_bid != 0) {
            auction.bidders[msg.sender] += msg.value;
        }
        
         else {
            revert("you've not placed a bid");
        }
        uint current_bid = auction.bidders[msg.sender];
        if (current_bid > auction.highestBid) {
            auction.highestbidder = msg.sender;
            auction.highestBid = current_bid;
        }
    }

    function withdraw(uint256 _auctionid) public {
        AuctionItem storage aunction = auctionItems[_auctionid];
        require(aunction.bidders[msg.sender] > 0, "You don't have a bid.");

        uint amount = (aunction.bidders[msg.sender] * 9) / 10;

        if (msg.sender != address(0)) {
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success, "Transfer failed.");
            aunction.bidders[msg.sender] = 0;
        } else {
            revert("invalid caller");
        }
    }

    function endAuction(uint256 _auctionId) public onlyAdmin {
        AuctionItem storage item = auctionItems[_auctionId];
        require(item.auctionStarted, "Auction not in progress");

        address bidders;
        // for (uint i = 0; i < item.Bids.length; i++) {
        //     if (item.Bids[i] > item.highestBid) {
        //         item.highestBid = item.Bids[i];
        //         item.highestbidder = item.getbidders[item.highestBid];
        //     }
        // }

        item.nftAddress;

        IERC721 price = IERC721(item.nftAddress);
        item.auctionStarted = false;
        if (bidders == address(0)) {
            price.safeTransferFrom(address(this), _owner, item.nftId);
        } else {
            price.safeTransferFrom(address(this), bidders, item.nftId);
            payable(owner()).transfer(item.highestBid);
        }
    }

    function withdrawNft(uint256 _auctionId, address _to) public onlyAdmin {
        AuctionItem storage item = auctionItems[_auctionId];

        IERC721 price = IERC721(item.nftAddress);
        require(!item.auctionStarted, "Auction is still ongoing.");
        require(price.ownerOf(item.nftId) == address(this), "nft not present");
        price.safeTransferFrom(address(this), _to, item.nftId);
    }

    receive() external payable {}

    fallback() external payable {}
}
