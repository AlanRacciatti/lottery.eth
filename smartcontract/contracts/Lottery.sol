// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
import "hardhat/console.sol";

contract LotteryGame is VRFConsumerBase {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    struct Lottery {
        uint256 lotteryId;
        address[] participants;
        uint256 ticketPrice;
        uint256 prize;
        address winner;
        bool isFinished;
        uint256 endDate;
    }

    Counters.Counter private lotteryId;
    mapping(uint256 => Lottery) private lotteries;
    mapping(bytes32 => uint256) private lotteryRandomnessRequest;
    mapping(uint256 => mapping(address => uint256)) public ppplayer; //participations per player
    mapping(uint256 => uint256) public playersCount;
    bytes32 private keyHash;
    uint256 private fee;

    event RandomnessRequested(bytes32, uint256);
    event WinnerDeclared(bytes32, uint256, address);
    event LotteryFinished(uint256, address);
    event PrizeIncreased(uint256, uint256);
    event LotteryCreated(uint256, uint256, uint256, uint256);

    constructor(
        address vrfCoordinator,
        address link,
        bytes32 _keyhash,
        uint256 _fee
    ) VRFConsumerBase(vrfCoordinator, link) {
        keyHash = _keyhash;
        fee = _fee;
    }

    function createLottery(uint256 _ticketPrice, uint256 _seconds)
        public
        payable
    {
        // solhint-disable-next-line
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        // solhint-disable-next-line
        require(_seconds > 0, "Lottery time must be greater than 0");
        Lottery memory lottery = Lottery({
            lotteryId: lotteryId.current(),
            participants: new address[](0),
            prize: 0,
            ticketPrice: _ticketPrice,
            winner: address(0),
            isFinished: false,
            //solhint-disable-next-line "not-rely-on-time": false
            endDate: block.timestamp + _seconds * 1 seconds
        });
        lotteries[lotteryId.current()] = lottery;
        lotteryId.increment();
        emit LotteryCreated(
            lottery.lotteryId,
            lottery.ticketPrice,
            lottery.prize,
            lottery.endDate
        );
    }

    function participate(uint256 _lotteryId) public payable {
        Lottery storage lottery = lotteries[_lotteryId];
        require(block.timestamp < lottery.endDate,"Lottery participation is closed");
        require(lottery.ticketPrice == msg.value, "Value must be equal to ticket price");
        lottery.participants.push(msg.sender);
        lottery.prize += msg.value;
        uint256 uniqueP = ppplayer[_lotteryId][msg.sender];
        if(uniqueP == 0) {
            playersCount[_lotteryId]++;
        }
        ppplayer[_lotteryId][msg.sender]++;

        emit PrizeIncreased(lottery.lotteryId, lottery.prize);
    }

    function declareWinner(uint256 _lotteryId) public {
        Lottery storage lottery = lotteries[_lotteryId];
        require(block.timestamp > lottery.endDate,"Lottery is still active");
        require(!lottery.isFinished,"Lottery has already declared a winner");
        lottery.isFinished = true;
        if (playersCount[_lotteryId] == 0) {
            lottery.winner = address(0);
            emit LotteryFinished(lottery.lotteryId, lottery.winner);
        } else if(playersCount[_lotteryId] == 1) {
            require(lottery.participants[0] != address(0), "There has been no participation in this lottery");
            lottery.winner = lottery.participants[0];
            (bool success, ) = lottery.winner.call{value: lottery.prize }("");
            require(success, "Transfer failed");
            emit LotteryFinished(lottery.lotteryId, lottery.winner);
        } else {
            require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
            bytes32 requestId = requestRandomness(keyHash, fee);
            lotteryRandomnessRequest[requestId] = _lotteryId;
            emit RandomnessRequested(requestId,_lotteryId);
        }
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 _lotteryId = lotteryRandomnessRequest[requestId];
        Lottery storage lottery = lotteries[_lotteryId];
        uint256 winner = randomness.mod(lottery.participants.length);
        lottery.winner = lottery.participants[winner];
        delete lotteryRandomnessRequest[requestId];
        delete playersCount[_lotteryId];
        (bool success, ) = lottery.winner.call{value: lottery.prize }("");
        require(success, "Transfer failed");
        emit WinnerDeclared(requestId,lottery.lotteryId,lottery.winner);
    }

    function getLottery(uint256 _lotteryId) public view returns (Lottery memory) {
        return lotteries[_lotteryId];
    }

    function getLotteryCount() public view returns (uint256) {
        return lotteryId.current();
    }

    function getLotteries() public view returns (Lottery[] memory) {
        Lottery[] memory allLotteries = new Lottery[](lotteryId.current());
        for (uint256 i = 0; i < lotteryId.current(); i++) {
            allLotteries[i] = getLottery(i);
        }
        return allLotteries;
    }
}
